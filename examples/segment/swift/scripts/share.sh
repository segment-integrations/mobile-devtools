#!/usr/bin/env bash
#
# share.sh - Package Swift repro for sharing
#
# Creates a zip archive of the reproduction case for easy sharing
# via Jira, email, or other channels.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 Swift Repro Share Tool${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "This tool requires git to track changes."
    exit 1
fi

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
REPRO_DIR="$PWD"
RELATIVE_PATH=$(realpath --relative-to="$REPO_ROOT" "$REPRO_DIR" 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$REPRO_DIR', '$REPO_ROOT'))")

echo -e "${BLUE}Repository:${NC} $REPO_ROOT"
echo -e "${BLUE}Repro directory:${NC} $RELATIVE_PATH"
echo ""

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}Found uncommitted changes:${NC}"
    git status --short
    echo ""

    echo -e "${BLUE}Committing changes...${NC}"

    # Add all changes in the repro directory
    git add .

    # Create commit with timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    git commit -m "Repro: Swift SDK reproduction case - $TIMESTAMP" \
               -m "Auto-committed by share.sh for reproduction sharing." \
               -m "Changes include modifications to demonstrate customer issue." \
               -m "" \
               -m "Co-Authored-By: Share Script <noreply@segment.com>"

    echo -e "${GREEN}✓ Changes committed${NC}"
    echo ""
else
    echo -e "${GREEN}✓ No uncommitted changes${NC}"
    echo ""
fi

# Get commit information
COMMIT_HASH=$(git rev-parse --short HEAD)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
ARCHIVE_NAME="swift-repro-${COMMIT_HASH}-${TIMESTAMP}"
OUTPUT_DIR="$REPO_ROOT/shared-repros"
ARCHIVE_PATH="$OUTPUT_DIR/${ARCHIVE_NAME}.zip"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}Creating archive...${NC}"
echo -e "  Name: ${ARCHIVE_NAME}.zip"
echo ""

# Create temporary staging directory
TEMP_DIR=$(mktemp -d)
STAGING_DIR="$TEMP_DIR/$ARCHIVE_NAME"
mkdir -p "$STAGING_DIR"

# Copy relevant files, excluding build artifacts and large files
echo -e "${BLUE}Copying files...${NC}"

# Copy the entire repro directory structure but exclude certain patterns
rsync -a \
  --exclude='.git' \
  --exclude='DerivedData' \
  --exclude='*.xcuserstate' \
  --exclude='xcuserdata' \
  --exclude='*.xcworkspace' \
  --exclude='.DS_Store' \
  --exclude='build' \
  --exclude='.devbox' \
  --exclude='node_modules' \
  "$REPRO_DIR/" "$STAGING_DIR/"

# Add a README with reproduction info
cat > "$STAGING_DIR/REPRO-INFO.txt" << EOF
Swift SDK Reproduction Case
============================

Commit: $COMMIT_HASH
Created: $(date '+%Y-%m-%d %H:%M:%S')
Repository: mobile-devtools

This reproduction case demonstrates a reported issue with the Segment Analytics Swift SDK.

Setup Instructions:
-------------------
1. Extract this zip file
2. Open Terminal and navigate to the extracted directory:
   cd path/to/$ARCHIVE_NAME

3. Install Devbox if not already installed:
   curl -fsSL https://get.jetify.com/devbox | bash

4. Build and run the reproduction:
   devbox run --pure start:app

5. Tap buttons in the simulator to trigger the issue
6. Check Terminal output for logged events

For detailed instructions, see README.md in this directory.

Questions?
----------
Refer to the README.md or contact the Mobile SDK team.
EOF

# Create git patch for the changes
echo -e "${BLUE}Creating git patch...${NC}"
git format-patch -1 HEAD --stdout > "$STAGING_DIR/changes.patch"

# Create the zip archive
echo -e "${BLUE}Compressing...${NC}"
cd "$TEMP_DIR"
zip -r "$ARCHIVE_PATH" "$ARCHIVE_NAME" > /dev/null

# Get file size before cleanup
FILE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)

# Clean up and return to original directory
rm -rf "$TEMP_DIR"
cd "$REPRO_DIR"

echo ""
echo -e "${GREEN}✅ Archive created successfully!${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Archive Details:${NC}"
echo -e "  Name:     ${ARCHIVE_NAME}.zip"
echo -e "  Size:     ${FILE_SIZE}"
echo -e "  Location: ${ARCHIVE_PATH}"
echo -e "  Commit:   ${COMMIT_HASH}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show git log for context
echo -e "${BLUE}Recent changes:${NC}"
git log -1 --pretty=format:"  %h - %s%n  Author: %an <%ae>%n  Date:   %ad%n" --date=format:'%Y-%m-%d %H:%M:%S'
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo -e "1️⃣  ${BLUE}Locate the file:${NC}"
echo "   Open Finder and navigate to:"
echo "   ${ARCHIVE_PATH/$HOME/~}"
echo ""
echo -e "2️⃣  ${BLUE}Upload to Jira:${NC}"
echo "   • Open the Jira issue in your browser"
echo "   • Click 'Attach' or drag the zip file onto the issue"
echo "   • Add a comment describing what you changed"
echo ""
echo -e "3️⃣  ${BLUE}Or share via email:${NC}"
echo "   • Attach the zip file to your email"
echo "   • Mention the commit hash: ${COMMIT_HASH}"
echo ""
echo -e "${YELLOW}Note:${NC} The archive excludes build artifacts and is ready to share."
echo -e "${YELLOW}      The recipient can extract and run: devbox run --pure start:app${NC}"
echo ""

# Copy path to clipboard if pbcopy is available (macOS)
if command -v pbcopy &> /dev/null; then
    echo -n "$ARCHIVE_PATH" | pbcopy
    echo -e "${GREEN}✓ Archive path copied to clipboard!${NC}"
    echo ""
fi
