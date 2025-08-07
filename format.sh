#!/bin/bash

PROJECT_ROOT="$(pwd)"

if ! command -v swift-format &> /dev/null; then
    echo "please install swift-format first"
    exit 1
fi

echo "formatting Swift files..."
find "$PROJECT_ROOT" -name "*.swift" -not -path "*/Carthage/*" -not -path "*/Pods/*" | while read -r file; do
    echo "formatting: $file"
    swift-format format --in-place "$file"
done

echo "formatting completed"