#!/bin/bash
# Master Automation Script for Payroll XML Files
# Runs all transformation tools in the correct order

set -e

TOOLS_DIR="$(dirname "$0")"
PYTHON_CMD="python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} Payroll XML Automation Suite${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_step() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

usage() {
    echo "Usage: $0 <xml_file_path> [options]"
    echo "       $0 --batch <directory_path> [options]"
    echo ""
    echo "Options:"
    echo "  --mapping-only       Only generate column mapping"
    echo "  --siglas-only        Only add sigla descriptions" 
    echo "  --formulas-only      Only translate formulas"
    echo "  --single-send-only   Only map singleSendRecord"
    echo "  --skip-mapping       Skip column mapping generation"
    echo "  --skip-siglas        Skip sigla descriptions"
    echo "  --skip-formulas      Skip formula translation"
    echo "  --skip-single-send   Skip singleSendRecord mapping"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 file.xml                    # Run all transformations"
    echo "  $0 file.xml --formulas-only   # Only translate formulas"
    echo "  $0 --batch ./nomina/           # Process all XML files in directory"
}

process_file() {
    local file="$1"
    local run_mapping="$2"
    local run_siglas="$3" 
    local run_formulas="$4"
    local run_single_send="$5"
    
    echo ""
    echo -e "${BLUE}📁 Processing: $(basename "$file")${NC}"
    echo "----------------------------------------"
    
    # Step 1: Column Mapping
    if [ "$run_mapping" = "true" ]; then
        print_step "Generating column mapping..."
        if $PYTHON_CMD "$TOOLS_DIR/column_mapping_generator.py" "$file"; then
            print_success "Column mapping completed"
        else
            print_error "Column mapping failed"
            return 1
        fi
    fi
    
    # Step 2: Sigla Descriptions
    if [ "$run_siglas" = "true" ]; then
        print_step "Adding sigla descriptions..."
        if $PYTHON_CMD "$TOOLS_DIR/add_sigla_descriptions.py" "$file"; then
            print_success "Sigla descriptions completed"
        else
            print_error "Sigla descriptions failed"
            return 1
        fi
    fi
    
    # Step 3: Formula Translation
    if [ "$run_formulas" = "true" ]; then
        print_step "Translating formulas..."
        if $PYTHON_CMD "$TOOLS_DIR/formula_translator.py" "$file"; then
            print_success "Formula translation completed"
        else
            print_error "Formula translation failed"
            return 1
        fi
    fi
    
    # Step 4: SingleSendRecord Mapping
    if [ "$run_single_send" = "true" ]; then
        print_step "Mapping singleSendRecord..."
        if $PYTHON_CMD "$TOOLS_DIR/single_send_record_mapper.py" "$file"; then
            print_success "SingleSendRecord mapping completed"
        else
            print_error "SingleSendRecord mapping failed"
            return 1
        fi
    fi
    
    print_success "File processing completed: $(basename "$file")"
}

main() {
    # Default options
    local run_mapping="true"
    local run_siglas="true"
    local run_formulas="true" 
    local run_single_send="true"
    local batch_mode="false"
    local target_path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                usage
                exit 0
                ;;
            --batch)
                batch_mode="true"
                target_path="$2"
                shift 2
                ;;
            --mapping-only)
                run_mapping="true"
                run_siglas="false"
                run_formulas="false"
                run_single_send="false"
                shift
                ;;
            --siglas-only)
                run_mapping="false"
                run_siglas="true"
                run_formulas="false"
                run_single_send="false"
                shift
                ;;
            --formulas-only)
                run_mapping="false"
                run_siglas="false"
                run_formulas="true"
                run_single_send="false"
                shift
                ;;
            --single-send-only)
                run_mapping="false"
                run_siglas="false"
                run_formulas="false"
                run_single_send="true"
                shift
                ;;
            --skip-mapping)
                run_mapping="false"
                shift
                ;;
            --skip-siglas)
                run_siglas="false"
                shift
                ;;
            --skip-formulas)
                run_formulas="false"
                shift
                ;;
            --skip-single-send)
                run_single_send="false"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [ "$batch_mode" = "false" ] && [ -z "$target_path" ]; then
                    target_path="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$target_path" ]; then
        print_error "No file or directory specified"
        usage
        exit 1
    fi
    
    print_header
    
    local success_count=0
    local total_count=0
    
    if [ "$batch_mode" = "true" ]; then
        if [ ! -d "$target_path" ]; then
            print_error "Directory not found: $target_path"
            exit 1
        fi
        
        echo "🗂️  Batch processing directory: $target_path"
        
        # Find all XML files
        while IFS= read -r -d '' file; do
            total_count=$((total_count + 1))
            if process_file "$file" "$run_mapping" "$run_siglas" "$run_formulas" "$run_single_send"; then
                success_count=$((success_count + 1))
            fi
        done < <(find "$target_path" -name "*.xml" -type f -print0)
        
        if [ $total_count -eq 0 ]; then
            print_error "No XML files found in $target_path"
            exit 1
        fi
    else
        if [ ! -f "$target_path" ]; then
            print_error "File not found: $target_path"
            exit 1
        fi
        
        total_count=1
        if process_file "$target_path" "$run_mapping" "$run_siglas" "$run_formulas" "$run_single_send"; then
            success_count=1
        fi
    fi
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    if [ $success_count -eq $total_count ]; then
        print_success "All $total_count file(s) processed successfully! 🎉"
    else
        print_error "Processed $success_count/$total_count files successfully"
        exit 1
    fi
}

main "$@"