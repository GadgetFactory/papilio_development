#!/usr/bin/env tclsh
# Simplified build script: ensure .gprj contains TopModule and set Gowin option
# Gowin Tcl API reference: https://cdn.gowinsemi.com.cn/SUG1220E.pdf
set gprj "papilio_arcade_template.gprj"

if {[file exists $gprj]} {
	set fh [open $gprj r]
	set content [read $fh]
	close $fh

	if {[regexp {<TopModule>.*</TopModule>} $content]} {
		regsub -all {<TopModule>.*</TopModule>} $content "<TopModule>top</TopModule>" newcontent
		set out $newcontent
	} else {
		regsub {(</Device>)} $content "\1\n    <TopModule>top</TopModule>" newcontent
		set out $newcontent
	}

	set fhw [open $gprj w]
	puts $fhw $out
	close $fhw
	puts "Updated $gprj with <TopModule>top</TopModule>"
} else {
	puts "Project file $gprj not found, continuing without modification"
}

open_project papilio_arcade_template.gprj

# Enable SystemVerilog support for HDMI modules
set_option -verilog_std sysv2017

# Preferred way to set top module in newer Gowin shells
if {[catch {set_option -top_module top} err]} {
	puts "set_option -top_module failed or not available: $err"
} else {
	puts "Set top module via set_option -top_module top"
}

run all