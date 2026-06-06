#!/bin/bash
# ================================================================
# CHOTTU AI - MAC LAUNCHER
# ================================================================
# Just double-click this file on any Mac to start your portable AI.
# Everything runs from the USB drive. Nothing is installed on the Mac.
# ================================================================

# Move to the USB drive directory where this script lives
cd "$(dirname "$0")"

USB_DIR=$(pwd)
MAC_OLLAMA_DIR="$USB_DIR/ollama_mac"
DATA_DIR="$USB_DIR/ollama/data"

echo "==================================================="
echo "       Launching Chottu AI for Mac...            "
echo "==================================================="

# -----------------------------------------------------------------
# STEP 1: Download Mac Ollama Engine (first time only)
# -----------------------------------------------------------------
if [ ! -d "$MAC_OLLAMA_DIR/Ollama.app" ] && [ ! -f "$MAC_OLLAMA_DIR/ollama" ]; then
    echo "First time on Mac! Downloading the AI Engine for Chottu..."
    mkdir -p "$MAC_OLLAMA_DIR"
    curl -L --progress-bar "https://github.com/ollama/ollama/releases/latest/download/ollama-darwin.zip" -o "$MAC_OLLAMA_DIR/ollama-darwin.zip"
    echo "Extracting..."
    unzip -o -q "$MAC_OLLAMA_DIR/ollama-darwin.zip" -d "$MAC_OLLAMA_DIR/"
    rm "$MAC_OLLAMA_DIR/ollama-darwin.zip"
    
    # Make executable
    if [ -f "$MAC_OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama" ]; then
        chmod +x "$MAC_OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama"
    elif [ -f "$MAC_OLLAMA_DIR/ollama" ]; then
        chmod +x "$MAC_OLLAMA_DIR/ollama"
    fi
    
    echo "Mac Engine Setup Complete for Chottu!"
    echo ""
fi

# -----------------------------------------------------------------
# STEP 2: Download Chottu Interface (first time only, fully portable!)
# -----------------------------------------------------------------
if [ ! -d "$USB_DIR/chottu_mac/Chottu.app" ] && [ ! -d "$USB_DIR/chottu_mac/AnythingLLM.app" ]; then
    echo "First time setup: Downloading Chottu directly to USB..."
    echo "NO installation on the Mac! Everything stays on the drive."
    mkdir -p "$USB_DIR/chottu_mac"
    
    # Download the DMG
    curl -L --progress-bar "https://cdn.anythingllm.com/latest/AnythingLLMDesktop-Silicon.dmg" -o "$USB_DIR/chottu_mac/Chottu_Installer.dmg"
    
    echo "Extracting Chottu to USB (please wait)..."
    # Mount the DMG silently and extract
    MOUNT_DIR=$(hdiutil attach -nobrowse "$USB_DIR/chottu_mac/Chottu_Installer.dmg" | grep -o '/Volumes/.*')
    
    # Copy the app to the USB and rename to Chottu
    cp -R "$MOUNT_DIR/AnythingLLM.app" "$USB_DIR/chottu_mac/Chottu.app"
    
    # Clean up
    hdiutil detach "$MOUNT_DIR"
    rm "$USB_DIR/chottu_mac/Chottu_Installer.dmg"
    
    # Remove Apple quarantine so it runs from USB without being blocked
    xattr -rc "$USB_DIR/chottu_mac/Chottu.app"
    
    echo "Chottu extracted and ready!"
fi

# Also check for legacy AnythingLLM and rename it
if [ -d "$USB_DIR/chottu_mac/AnythingLLM.app" ] && [ ! -d "$USB_DIR/chottu_mac/Chottu.app" ]; then
    echo "Found legacy AnythingLLM, renaming to Chottu..."
    mv "$USB_DIR/chottu_mac/AnythingLLM.app" "$USB_DIR/chottu_mac/Chottu.app"
    xattr -rc "$USB_DIR/chottu_mac/Chottu.app"
fi

# -----------------------------------------------------------------
# STEP 3: Launch the AI Engine
# -----------------------------------------------------------------
echo ""
echo "Starting Chottu AI Engine from USB..."

# Lock all data paths to the USB drive
export OLLAMA_MODELS="$DATA_DIR"
export STORAGE_DIR="$USB_DIR/chottu_data"
mkdir -p "$STORAGE_DIR"

# -----------------------------------------------------------------
# ENSURE CHOTTU USES EXTERNAL OLLAMA (not built-in)
# -----------------------------------------------------------------
ENV_FILE="$STORAGE_DIR/storage/.env"
mkdir -p "$STORAGE_DIR/storage"

# Read first model
DEFAULT_MODEL="nemomix-local"
if [ -f "$USB_DIR/models/installed-models.txt" ]; then
    DEFAULT_MODEL=$(head -n 1 "$USB_DIR/models/installed-models.txt" | cut -d '|' -f 1)
fi

NEEDS_FIX=0
if [ ! -f "$ENV_FILE" ]; then
    NEEDS_FIX=1
elif ! grep -q "LLM_PROVIDER=ollama" "$ENV_FILE" || grep -q "LLM_PROVIDER=anythingllm_ollama" "$ENV_FILE"; then
    NEEDS_FIX=1
fi

if [ "$NEEDS_FIX" = "1" ]; then
    echo "Configuring Chottu to use external Ollama engine..."
    cat > "$ENV_FILE" << EOF
LLM_PROVIDER=ollama
OLLAMA_BASE_PATH=http://127.0.0.1:11434
OLLAMA_MODEL_PREF=$DEFAULT_MODEL
OLLAMA_MODEL_TOKEN_LIMIT=4096
EMBEDDING_ENGINE=native
VECTOR_DB=lancedb
EOF
fi

# -------------------------------------------------------
# SHOW INSTALLED MODELS
# -------------------------------------------------------
if [ -f "$USB_DIR/models/installed-models.txt" ]; then
    echo ""
    echo "Installed models:"
    while IFS="|" read -r local_name nice_name tag; do
        if [ ! -z "$nice_name" ]; then
            echo "  - $nice_name [$tag]"
        fi
    done < "$USB_DIR/models/installed-models.txt"
    echo ""
fi

# Start Ollama in background
if [ -f "$MAC_OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama" ]; then
    "$MAC_OLLAMA_DIR/Ollama.app/Contents/MacOS/Ollama" serve > /dev/null 2>&1 &
elif [ -f "$MAC_OLLAMA_DIR/ollama" ]; then
    "$MAC_OLLAMA_DIR/ollama" serve > /dev/null 2>&1 &
else
    echo "Error: Could not find the Ollama binary on the USB drive!"
fi
OLLAMA_PID=$!

sleep 3

echo ""
echo "==================================================="
echo "     CHOTTU ONLINE: Your AI is running from USB!   "
echo "==================================================="
echo ""

# -----------------------------------------------------------------
# STEP 4: Launch Chottu Interface
# -----------------------------------------------------------------
echo ""
echo "Starting Chottu Interface from USB..."

# CRITICAL: We MUST wipe Electron path caches for true portability!
# This fixes the "JavaScript error" when moving USBs between different Macs.
[ -f "$STORAGE_DIR/config.json" ] && rm "$STORAGE_DIR/config.json"
[ -d "$STORAGE_DIR/Cache" ] && rm -rf "$STORAGE_DIR/Cache"
[ -d "$STORAGE_DIR/Code Cache" ] && rm -rf "$STORAGE_DIR/Code Cache"
[ -d "$STORAGE_DIR/GPUCache" ] && rm -rf "$STORAGE_DIR/GPUCache"

# Launch Chottu from USB
if [ -d "$USB_DIR/chottu_mac/Chottu.app" ]; then
    echo "Opening Chottu..."
    open -a "$USB_DIR/chottu_mac/Chottu.app" --args --user-data-dir="$STORAGE_DIR"
elif [ -d "$USB_DIR/anythingllm_mac/AnythingLLM.app" ]; then
    echo "Legacy installation found. Migrating to Chottu..."
    mv "$USB_DIR/anythingllm_mac/AnythingLLM.app" "$USB_DIR/chottu_mac/Chottu.app"
    open -a "$USB_DIR/chottu_mac/Chottu.app" --args --user-data-dir="$STORAGE_DIR"
else
    echo "Error: Chottu.app not found on USB drive!"
    echo "Please run install.sh first or check your USB drive."
    exit 1
fi

echo ""
echo "Keep this terminal open while you chat!"
echo "Press [ENTER] to shut down Chottu AI safely."
echo ""

# Wait for user, then clean shutdown
read -p "Hit [ENTER] to turn off the Engine..."
kill $OLLAMA_PID 2>/dev/null
killall Chottu 2>/dev/null
killall AnythingLLM 2>/dev/null
echo ""
echo "Chottu AI shut down. You may safely eject the USB."