# HQVGA Synthesis Test for Gowin FPGA
# Tests if VHDL code compiles and synthesizes

# Open project
set project_path [file dirname [info script]]
cd $project_path
puts "Project directory: $project_path"

set project_file "hqvga_test.gprj"
puts "Opening project: $project_file"
open_project $project_file

# Set top module
set_option -top_module hqvga_test_top

# Run synthesis
run syn

puts "\n========================================="
puts "HQVGA Synthesis Test Complete"
puts "Check synthesis report for:"
puts "  - RAM inference (should see BSRAM usage)"
puts "  - Resource utilization"
puts "  - Any errors or warnings"
puts "=========================================\n"
