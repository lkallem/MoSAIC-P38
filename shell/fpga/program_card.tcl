########################################################################
#    By : Laura K                                                      #
#    Date : 8/18/2026                                                  #
#    Description : New program_card.tcl that takes an argument for     #
#                  which board to use.                                 #
########################################################################

#- board
if {$argc == 0} {
    error "The -board option is required. Usage: -board <u250|u280>"
}
if {$argc == 1 && [lindex $argv 0] eq "-board"} {
    error "A value is required for -board. Valid values are u250 and u280."
}
if {$argc != 2 || [lindex $argv 0] ne "-board"} {
    error "Usage: -board <u250|u280>"
}
set board [lindex $argv 1]
switch -- $board {
    u250 {
        set device_name xcu250_0
    }
    u280 {
        set device_name xcu280_u55c_0
    }
    default {
        error "Unsupported board '$board'. Valid values are u250 and u280."
    }
}
puts "Board: $board"
puts "HW device: $device_name"

#####################################################
#                                                   #
#   Change the bit file to match your experiment!   #
#                                                   #
#####################################################

set bit_file "./shell/fpga/${board}_bit/open_nic_shell.bit"

#####################################################

if {![file isfile $bit_file]} {
    error "Bitfile not found: $bit_file"
}

puts "Program file: $bit_file"

#- The meat and potatoes
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set hw_device [lindex [get_hw_devices $device_name] 0]
if {$hw_device eq ""} {
    error "Hardware device not found: $device_name"
}

current_hw_device $hw_device
refresh_hw_device -update_hw_probes false $hw_device

# Optionally, set your probes file here
#set_property PROBES.FILE {./${board}_bit/my_ltx_file.ltx} $hw_device
#set_property FULL_PROBES.FILE {./${board}_bit/my_ltx_file.ltx} $hw_device
set_property PROGRAM.FILE $bit_file $hw_device
#- Hardcode the path here if you'd like
# set_property PROGRAM.FILE {/home/lkallem/mosaic/open-nic-shell-lbnl/build/au250/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.bit} $hw_device

program_hw_devices $hw_device
refresh_hw_device $hw_device
