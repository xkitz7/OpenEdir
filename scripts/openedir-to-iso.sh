#!/bin/bash

# OpenEdir Automated Build Script
set -euo pipefail  # Strict error handling

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/xkitz7/OpenEdir.git"
WORK_DIR="./openedir-build"
ISO_DIR="./iso"
BOOT_DIR="./boot"
LOG_FILE="./build.log"
BUILD_DIR="./build"

# Function for colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Error handling and cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Build failed. Check $LOG_FILE for details."
    fi
    # Add any specific cleanup here if needed
}

trap cleanup EXIT

# Check and install dependencies
install_dependencies() {
    log_info "Checking and installing build dependencies..."
    
    local deps=("nasm" "gcc" "make" "genisoimage" "git" "mtools" "qemu-system-x86")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_warning "Missing dependencies: ${missing[*]}"
        
        if command -v apt-get &> /dev/null; then
            log_info "Installing dependencies using apt..."
            sudo apt-get update && sudo apt-get install -y "${missing[@]}" || {
                log_error "Failed to install dependencies"
                return 1
            }
        elif command -v yum &> /dev/null; then
            log_info "Installing dependencies using yum..."
            sudo yum install -y "${missing[@]}" || {
                log_error "Failed to install dependencies"
                return 1
            }
        else
            log_error "Cannot install dependencies automatically. Please install manually: ${missing[*]}"
            return 1
        fi
    else
        log_success "All dependencies are already installed"
    fi
}

# Clone or update repository
setup_repository() {
    log_info "Setting up repository..."
    
    if [ ! -d "$WORK_DIR" ]; then
        log_info "Cloning repository from $REPO_URL..."
        if git clone "$REPO_URL" "$WORK_DIR" 2>> "$LOG_FILE"; then
            log_success "Repository cloned successfully"
        else
            log_error "Failed to clone repository"
            return 1
        fi
    else
        log_info "Updating existing repository..."
        cd "$WORK_DIR"
        if git pull 2>> "$LOG_FILE"; then
            log_success "Repository updated successfully"
        else
            log_warning "Git pull had issues, but continuing..."
        fi
        cd - > /dev/null
    fi
    
    # Verify repository structure
    if [ ! -d "$WORK_DIR/krnl" ] || [ ! -d "$WORK_DIR/boot" ]; then
        log_error "Repository structure invalid. Missing krnl/ or boot/ directories"
        return 1
    fi
}

# Build the bootloader and kernel
compile_project() {
    log_info "Compiling OpenEdir project..."
    
    cd "$WORK_DIR"
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Run CMake configuration
    log_info "Configuring build with CMake..."
    if ! cmake .. 2>> "$LOG_FILE"; then
        log_error "CMake configuration failed"
        return 1
    fi
    
    # Compile with all available cores
    local cores=$(nproc)
    log_info "Compiling with $cores cores..."
    if ! make -j"$cores" 2>> "$LOG_FILE"; then
        log_error "Compilation failed"
        return 1
    fi
    
    cd - > /dev/null
    log_success "Compilation completed successfully"
}

# Build individual components (fallback if CMake fails)
build_components() {
    log_info "Building components manually..."
    cd "$WORK_DIR"
    
    # Build bootloader
    log_info "Building bootloader..."
    if ! nasm -f bin boot/boot.asm -o boot.bin 2>> "$LOG_FILE"; then
        log_error "Bootloader assembly failed"
        return 1
    fi
    
    # Build multiboot header
    log_info "Building multiboot header..."
    if ! nasm -f elf32 boot/multiboot.asm -o multiboot.o 2>> "$LOG_FILE"; then
        log_error "Multiboot assembly failed"
        return 1
    fi
    
    # Build kernel components with proper flags
    log_info "Building kernel components..."
    local c_files=$(find krnl/src -name "*.c")
    for c_file in $c_files; do
        local obj_name=$(basename "$c_file" .c).o
        if ! gcc -m32 -ffreestanding -nostdlib -nostartfiles -nodefaultlibs \
             -Ikrnl/include -c "$c_file" -o "$obj_name" 2>> "$LOG_FILE"; then
            log_error "Compilation failed for $c_file"
            return 1
        fi
    done
    
    # Link kernel
    log_info "Linking kernel..."
    local obj_files=$(find . -name "*.o" | tr '\n' ' ')
    if ! ld -m elf_i386 -T boot/linker.ld -o kernel.bin $obj_files 2>> "$LOG_FILE"; then
        log_error "Linking failed"
        return 1
    fi
    
    cd - > /dev/null
    log_success "Manual build completed successfully"
}

# Create ISO structure and generate ISO
create_iso() {
    log_info "Creating ISO structure..."
    
    # Clean and create ISO directory
    rm -rf "$ISO_DIR"
    mkdir -p "$ISO_DIR/boot/grub"
    
    # Copy necessary files
    cp "$WORK_DIR/boot.bin" "$ISO_DIR/boot/" 2>> "$LOG_FILE" || {
        log_error "Failed to copy bootloader"
        return 1
    }
    
    cp "$WORK_DIR/kernel.bin" "$ISO_DIR/boot/" 2>> "$LOG_FILE" || {
        log_error "Failed to copy kernel"
        return 1
    }
    
    # Create GRUB configuration
    cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=0
set default=0

menuentry "OpenEdir" {
    multiboot /boot/kernel.bin
    boot
}
EOF
    
    # Generate ISO
    log_info "Generating ISO image..."
    local iso_name="openedir-$(date +%Y%m%d-%H%M%S).iso"
    
    if genisoimage -R -b boot/grub/stage2_eltorito -no-emul-boot \
        -boot-load-size 4 -boot-info-table -input-charset utf-8 \
        -o "$iso_name" "$ISO_DIR" 2>> "$LOG_FILE"; then
        log_success "ISO created: $iso_name"
        
        # Display ISO info
        local size=$(du -h "$iso_name" | cut -f1)
        log_info "ISO size: $size"
    else
        log_error "ISO creation failed"
        return 1
    fi
}

# Test the build (optional)
test_build() {
    if command -v qemu-system-x86_64 &> /dev/null; then
        log_info "Testing build with QEMU..."
        local iso_name=$(ls openedir-*.iso | head -1)
        if [ -n "$iso_name" ]; then
            log_info "Starting QEMU with $iso_name (Ctrl+A then X to exit)"
            qemu-system-x86_64 -cdrom "$iso_name" -m 512 -no-reboot -no-shutdown
        fi
    else
        log_warning "QEMU not available. Install qemu-system-x86 to test the ISO."
    fi
}

# Main execution
main() {
    log_info "=== OpenEdir Build Process Started ==="
    log_info "Log file: $LOG_FILE"
    
    # Initialize log file
    echo "OpenEdir build started at $(date)" > "$LOG_FILE"
    
    # Execute build steps
    install_dependencies || exit 1
    setup_repository || exit 1
    
    # Try CMake build first, fall back to manual build
    if ! compile_project; then
        log_warning "CMake build failed, attempting manual build..."
        build_components || exit 1
    fi
    
    create_iso || exit 1
    
    log_success "=== OpenEdir Build Complete ==="
    
    # Offer to test the build
    read -p "Do you want to test the build with QEMU? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_build
    fi
}

# Create build log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"
