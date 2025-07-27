#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_current_branch() {
    print_info "Checking current branch..."
    current_branch=$(git branch --show-current)
    
    if [ "$current_branch" != "dev" ]; then
        print_error "Current branch is '$current_branch', but should be 'dev'"
        print_info "Please switch to dev branch: git checkout dev"
        exit 1
    fi
    
    print_success "Current branch is dev"
}

check_working_directory() {
    print_info "Checking working directory status..."
    
    if ! git diff-index --quiet HEAD --; then
        print_error "Working directory has uncommitted changes"
        print_info "Please commit or stash changes first"
        exit 1
    fi
    
    print_success "Working directory is clean"
}

fetch_latest() {
    print_info "Fetching latest changes..."
    git fetch origin
    print_success "Fetch completed"
}

show_rebase_summary() {
    print_info "Showing commits to be rebased..."
    
    commits_ahead=$(git log --oneline main..HEAD)
    
    if [ -z "$commits_ahead" ]; then
        print_warning "No commits ahead of main in dev branch"
        return 0
    fi
    
    echo ""
    print_info "Following commits will be rebased to main:"
    echo "$commits_ahead"
    echo ""
}

perform_rebase() {
    print_info "Starting rebase to main..."
    
    if ! git rebase origin/main; then
        print_error "Rebase failed, please resolve conflicts manually and retry"
        print_info "You can abort rebase with: git rebase --abort"
        exit 1
    fi
    
    print_success "Rebase completed"
}

show_final_summary() {
    print_info "Showing final summary..."
    
    echo ""
    print_info "=== REBASE SUMMARY ==="
    echo "Source branch: dev"
    echo "Target branch: main"
    echo "Current commit: $(git rev-parse --short HEAD)"
    echo "Commit message: $(git log -1 --pretty=format:'%s')"
    echo ""
    
    print_info "Recent commits:"
    git log --oneline -5
    echo ""
}

confirm_push() {
    echo -n "Confirm push to main? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        print_warning "Operation cancelled"
        exit 0
    fi
}

push_to_main() {
    print_info "Pushing to main branch..."
    
    if git push origin dev:main; then
        print_success "Successfully pushed to main branch"
        print_info "Auto build should be triggered"
    else
        print_error "Push failed"
        exit 1
    fi
}

main() {
    print_info "Starting sync dev to main process..."
    echo ""
    
    check_current_branch
    check_working_directory
    fetch_latest
    show_rebase_summary
    perform_rebase
    show_final_summary
    confirm_push
    push_to_main
    
    echo ""
    print_success "Sync completed!"
}

main "$@"
