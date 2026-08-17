#!/usr/bin/perl
# *************************************************************************
# 
# *** Copyright Notice ***
#
# P38 heterogeneous multi-tiled system with support for message queues 
# (MoSAIC) Copyright (c) 2024, The Regents of the University of California, 
# through Lawrence Berkeley National Laboratory (subject to receipt of
# any required approvals from the U.S. Dept. of Energy). All rights reserved.
# 
# If you have questions about your rights to use or distribute this software,
# please contact Berkeley Lab's Intellectual Property Office at
# IPO@lbl.gov.
#
# NOTICE.  This Software was developed under funding from the U.S. Department
# of Energy and the U.S. Government consequently retains certain rights.  As
# such, the U.S. Government has been granted for itself and others acting on
# its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the
# Software to reproduce, distribute copies to the public, prepare derivative 
# works, and perform publicly and display publicly, and to permit others 
# to do so.
#
# *************************************************************************

use lib "$ENV{PWD}";
use lib "$ENV{PWD}/../picorv_c/c_long_pkt";
use gen_mosaic;
use gen_hex;
use POSIX;

###########################################
#- Set hash for parameters: Do not modify
###########################################

%param;

###########################################
#- Test case: Modify
###########################################

$path = "$ENV{PWD}";
print "INFO: Current directory: $path\n";

#- Firmware path
$fw_path = "$path/../picorv_c/c_long_pkt";
$param{'firmware_path'} = $fw_path;

#- 2x2 Tile array
$param{'r'} = 2;
$param{'c'} = 2;

@tile_array = (['pico', 'spad'],
               ['loop', 'pico']);

@pico_program  = ('long_pkt32_0.hex', '', '', 'recv_pkt32_9.hex');

#- Simulation Time
$param{'sim_loop'}     = 400;

#- Checkers
@checkers = ('check_long_pkt.sh');

#- Running with Vivado - do not turn off Vivado, simulation does not work in Icarus.
$param{'vivado'} = 1;
$param{'vivado_project'} = 1;
$param{'run_sim'} = 1;

#- C file
$c_file = 'long_pkt';

#- Generate hex code
chdir $fw_path or die "$!. $fw_path\n";
%param_h;
$param_h{'c_code'} = $c_file;
$param_h{'r'}      = $param{'r'}; 
$param_h{'c'}      = $param{'c'};             
$param_h{'keep'}   = 1; 
$param_h{'clean'}  = 1;
$param_h{'tile_array'} = \@tile_array;
gen_code(\%param_h);
#- C file
$c_file = 'recv_pkt';
$param_h{'c_code'} = $c_file;
gen_code(\%param_h);
chdir $path or die "$!. $path\n";

###########################################
#- Generate: Do not modify  
###########################################

$param{'checkers'} = \@checkers;
$param{'testcase'} = $0;
$param{'tile_array'} = \@tile_array;
$param{'pico_program'} = \@pico_program; 

gen_all(\%param);
