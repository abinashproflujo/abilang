#!/bin/bash
set -e

echo -e "\033[0;32m=========================================\033[0m"
echo -e "\033[0;32m    AbiLang macOS/Linux Auto-Installer   \033[0m"
echo -e "\033[0;32m=========================================\033[0m"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "\033[0;31mError: Node.js is missing! Please install Node.js (v18+) from https://nodejs.org/\033[0m"
    exit 1
else
    echo -e "\033[0;36mNode.js detected: $(node -v)\033[0m"
fi

# Install dependencies
echo -e "\033[0;36m1. Installing Node dependencies...\033[0m"
npm install

# Compile Project
echo -e "\033[0;36m2. Compiling TypeScript compiler...\033[0m"
npm run build

# Link executable
echo -e "\033[0;36m3. Registering global 'abi' command in system PATH...\033[0m"
sudo npm link || npm link

echo -e "\n\033[0;32mInstallation Completed Successfully!\033[0m"
echo -e "\033[0;33mYou can now run AbiLang scripts from any directory using: abi <script.vue>\033[0m"
echo -e "\033[0;33mTry starting the interactive console by typing: abi\033[0m"
