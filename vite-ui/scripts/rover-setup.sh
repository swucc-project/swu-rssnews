#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Apollo Rover Setup                                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Rover is already installed
if command -v rover &> /dev/null; then
    echo -e "${GREEN}✅ Rover is already installed${NC}"
    echo -e "   Version: $(rover --version)"
    echo ""
else
    echo -e "${YELLOW}📦 Installing Apollo Rover...${NC}"
    
    # ✅ URL ที่ถูกต้อง (มี v นำหน้า version)
    if curl -sSL https://rover.apollo.dev/nix/v0.36.2 | sh; then
        echo -e "${GREEN}✅ Rover installed successfully${NC}"
        
        # Add to PATH
        export PATH="$HOME/.rover/bin:$PATH"
        
        # Add to shell profile
        if [ -f "$HOME/.bashrc" ]; then
            if ! grep -q ".rover/bin" "$HOME/.bashrc"; then
                echo 'export PATH=$HOME/.rover/bin:$PATH' >> "$HOME/.bashrc"
                echo -e "${GREEN}✅ Added Rover to .bashrc${NC}"
            fi
        fi
        
        if [ -f "$HOME/.zshrc" ]; then
            if ! grep -q ".rover/bin" "$HOME/.zshrc"; then
                echo 'export PATH=$HOME/.rover/bin:$PATH' >> "$HOME/.zshrc"
                echo -e "${GREEN}✅ Added Rover to .zshrc${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Failed to install Rover${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ Rover Setup Complete!${NC}"