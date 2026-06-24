# Copyright (c) 2019 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# AXI stream asynchronous FIFO timing constraints

proc axis_async_fifo_dbg {msg} {
    puts "AXIS_ASYNC_FIFO_DBG: $msg"
    flush stdout
}

axis_async_fifo_dbg {000 before foreach get_cells axis_async_fifo}

foreach fifo_inst [get_cells -quiet -hier -filter {(ORIG_REF_NAME == axis_async_fifo || REF_NAME == axis_async_fifo)}] {
    axis_async_fifo_dbg [format {001 fifo=%s before catch block} $fifo_inst]

    # Set the constraints from within a catch block, so that if any of the statements fail to match any objects (e.g. because
    # one side of the FIFO is disconnected and gets optimized out), the script still completes.
    if { [catch {
        axis_async_fifo_dbg [format {002 fifo=%s before initial puts} $fifo_inst]
        puts "Inserting timing constraints for axis_async_fifo instance $fifo_inst"
        flush stdout
        axis_async_fifo_dbg [format {003 fifo=%s after initial puts} $fifo_inst]

        # get clock periods
        axis_async_fifo_dbg [format {004 fifo=%s before set read_clk get_clocks rd_ptr_reg_reg[0]/C} $fifo_inst]
        set rd_ptr0_cell_name [format {%s/rd_ptr_reg_reg[0]} $fifo_inst]
        axis_async_fifo_dbg [format {004a}]
        set rd_ptr0_cell [get_cells -quiet $rd_ptr0_cell_name]
        axis_async_fifo_dbg [format {004b}]
        if {[llength $rd_ptr0_cell] != 1} {
            puts "WARNING: expected one cell $rd_ptr0_cell_name, got [llength $rd_ptr0_cell]"
            continue
        }
        axis_async_fifo_dbg [format {004c}]
        
        set rd_ptr0_c_pin [get_pins -quiet -of_objects $rd_ptr0_cell -filter {REF_PIN_NAME == C}]
        axis_async_fifo_dbg [format {004d}]
        if {[llength $rd_ptr0_c_pin] != 1} {
            puts "WARNING: expected one C pin on $rd_ptr0_cell, got [llength $rd_ptr0_c_pin]"
            continue
        }
        axis_async_fifo_dbg [format {004e}]
        set read_clk [get_clocks -quiet -of_objects $rd_ptr0_c_pin]
        axis_async_fifo_dbg [format {004f}]
        if {[llength $read_clk]} {
            set read_clk_period [get_property -min PERIOD $read_clk]
        } else {
            puts "WARNING: no read clock found for $rd_ptr0_c_pin, using fallback period"
            set read_clk_period 1.0
        }
        axis_async_fifo_dbg [format {005 fifo=%s after set read_clk get_clocks rd_ptr_reg_reg[0]/C} $fifo_inst]

        axis_async_fifo_dbg [format {006 fifo=%s before set write_clk get_clocks wr_ptr_reg_reg[0]/C} $fifo_inst]
        set write_clk [get_clocks -of_objects [get_pins $fifo_inst/wr_ptr_reg_reg[0]/C]]
        axis_async_fifo_dbg [format {007 fifo=%s after set write_clk get_clocks wr_ptr_reg_reg[0]/C} $fifo_inst]

        axis_async_fifo_dbg [format {008 fifo=%s before set read_clk_period} $fifo_inst]
        set read_clk_period [get_property -min PERIOD $read_clk]
        axis_async_fifo_dbg [format {009 fifo=%s after set read_clk_period value=%s} $fifo_inst $read_clk_period]

        axis_async_fifo_dbg [format {010 fifo=%s before set write_clk_period} $fifo_inst]
        set write_clk_period [get_property -min PERIOD $write_clk]
        axis_async_fifo_dbg [format {011 fifo=%s after set write_clk_period value=%s} $fifo_inst $write_clk_period]

        axis_async_fifo_dbg [format {012 fifo=%s before set min_clk_period} $fifo_inst]
        set min_clk_period [expr $read_clk_period < $write_clk_period ? $read_clk_period : $write_clk_period]
        axis_async_fifo_dbg [format {013 fifo=%s after set min_clk_period value=%s} $fifo_inst $min_clk_period]

        # reset synchronization
        axis_async_fifo_dbg [format {014 fifo=%s before set reset_ffs} $fifo_inst]
        set reset_ffs [get_cells -quiet -hier -regexp ".*/(s|m)_rst_sync\[123\]_reg_reg" -filter "PARENT == $fifo_inst"]
        axis_async_fifo_dbg [format {015 fifo=%s after set reset_ffs count=%d} $fifo_inst [llength $reset_ffs]]

        axis_async_fifo_dbg [format {016 fifo=%s before reset_ffs if} $fifo_inst]
        if {[llength $reset_ffs]} {
            axis_async_fifo_dbg [format {017 fifo=%s before set_property ASYNC_REG reset_ffs} $fifo_inst]
            set_property ASYNC_REG TRUE $reset_ffs
            axis_async_fifo_dbg [format {018 fifo=%s after set_property ASYNC_REG reset_ffs} $fifo_inst]

            axis_async_fifo_dbg [format {019 fifo=%s before set_false_path reset preset pins} $fifo_inst]
            set_false_path -to [get_pins -of_objects $reset_ffs -filter {IS_PRESET || IS_RESET}]
            axis_async_fifo_dbg [format {020 fifo=%s after set_false_path reset preset pins} $fifo_inst]
        }
        axis_async_fifo_dbg [format {021 fifo=%s after reset_ffs if} $fifo_inst]

        axis_async_fifo_dbg [format {022 fifo=%s before s_rst_sync2 if} $fifo_inst]
        if {[llength [get_cells -quiet $fifo_inst/s_rst_sync2_reg_reg]]} {
            axis_async_fifo_dbg [format {023 fifo=%s before set_false_path s_rst_sync2 D} $fifo_inst]
            set_false_path -to [get_pins $fifo_inst/s_rst_sync2_reg_reg/D]
            axis_async_fifo_dbg [format {024 fifo=%s after set_false_path s_rst_sync2 D} $fifo_inst]

            axis_async_fifo_dbg [format {025 fifo=%s before set_max_delay s_rst_sync2 to s_rst_sync3} $fifo_inst]
            set_max_delay  -from [get_cells $fifo_inst/s_rst_sync2_reg_reg] -to [get_cells $fifo_inst/s_rst_sync3_reg_reg] $min_clk_period
            axis_async_fifo_dbg [format {026 fifo=%s after set_max_delay s_rst_sync2 to s_rst_sync3} $fifo_inst]
        }
        axis_async_fifo_dbg [format {027 fifo=%s after s_rst_sync2 if} $fifo_inst]

        axis_async_fifo_dbg [format {028 fifo=%s before m_rst_sync2 if} $fifo_inst]
        if {[llength [get_cells -quiet $fifo_inst/m_rst_sync2_reg_reg]]} {
            axis_async_fifo_dbg [format {029 fifo=%s before set_false_path m_rst_sync2 D} $fifo_inst]
            set_false_path -to [get_pins $fifo_inst/m_rst_sync2_reg_reg/D]
            axis_async_fifo_dbg [format {030 fifo=%s after set_false_path m_rst_sync2 D} $fifo_inst]

            axis_async_fifo_dbg [format {031 fifo=%s before set_max_delay m_rst_sync2 to m_rst_sync3} $fifo_inst]
            set_max_delay  -from [get_cells $fifo_inst/m_rst_sync2_reg_reg] -to [get_cells $fifo_inst/m_rst_sync3_reg_reg] $min_clk_period
            axis_async_fifo_dbg [format {032 fifo=%s after set_max_delay m_rst_sync2 to m_rst_sync3} $fifo_inst]
        }
        axis_async_fifo_dbg [format {033 fifo=%s after m_rst_sync2 if} $fifo_inst]

        # pointer synchronization
        axis_async_fifo_dbg [format {034 fifo=%s before set_property ASYNC_REG ptr gray sync regs} $fifo_inst]
        set_property ASYNC_REG TRUE [get_cells -hier -regexp ".*/(wr|rd)_ptr_gray_sync\[12\]_reg_reg\\\[\\d+\\\]" -filter "PARENT == $fifo_inst"]
        axis_async_fifo_dbg [format {035 fifo=%s after set_property ASYNC_REG ptr gray sync regs} $fifo_inst]

        axis_async_fifo_dbg [format {036 fifo=%s before set_max_delay rd_ptr to rd_ptr_gray_sync1} $fifo_inst]
        set_max_delay -from [get_cells "$fifo_inst/rd_ptr_reg_reg[*] $fifo_inst/rd_ptr_gray_reg_reg[*]"] -to [get_cells $fifo_inst/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only $read_clk_period
        axis_async_fifo_dbg [format {037 fifo=%s after set_max_delay rd_ptr to rd_ptr_gray_sync1} $fifo_inst]

        axis_async_fifo_dbg [format {038 fifo=%s before set_bus_skew rd_ptr to rd_ptr_gray_sync1} $fifo_inst]
        set_bus_skew  -from [get_cells "$fifo_inst/rd_ptr_reg_reg[*] $fifo_inst/rd_ptr_gray_reg_reg[*]"] -to [get_cells $fifo_inst/rd_ptr_gray_sync1_reg_reg[*]] $write_clk_period
        axis_async_fifo_dbg [format {039 fifo=%s after set_bus_skew rd_ptr to rd_ptr_gray_sync1} $fifo_inst]

        axis_async_fifo_dbg [format {040 fifo=%s before set_max_delay wr_ptr to wr_ptr_gray_sync1} $fifo_inst]
        set_max_delay -from [get_cells -quiet "$fifo_inst/wr_ptr_reg_reg[*] $fifo_inst/wr_ptr_gray_reg_reg[*] $fifo_inst/wr_ptr_sync_gray_reg_reg[*]"] -to [get_cells $fifo_inst/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only $write_clk_period
        axis_async_fifo_dbg [format {041 fifo=%s after set_max_delay wr_ptr to wr_ptr_gray_sync1} $fifo_inst]

        axis_async_fifo_dbg [format {042 fifo=%s before set_bus_skew wr_ptr to wr_ptr_gray_sync1} $fifo_inst]
        set_bus_skew  -from [get_cells -quiet "$fifo_inst/wr_ptr_reg_reg[*] $fifo_inst/wr_ptr_gray_reg_reg[*] $fifo_inst/wr_ptr_sync_gray_reg_reg[*]"] -to [get_cells $fifo_inst/wr_ptr_gray_sync1_reg_reg[*]] $read_clk_period
        axis_async_fifo_dbg [format {043 fifo=%s after set_bus_skew wr_ptr to wr_ptr_gray_sync1} $fifo_inst]

        # output register (needed for distributed RAM sync write/async read)
        axis_async_fifo_dbg [format {044 fifo=%s before set output_reg_ffs} $fifo_inst]
        set output_reg_ffs [get_cells -quiet "$fifo_inst/m_axis_pipe_reg_reg[0][*]"]
        axis_async_fifo_dbg [format {045 fifo=%s after set output_reg_ffs count=%d} $fifo_inst [llength $output_reg_ffs]]

        axis_async_fifo_dbg [format {046 fifo=%s before output_reg_ffs if} $fifo_inst]
        if {[llength $output_reg_ffs]} {
            axis_async_fifo_dbg [format {047 fifo=%s before set_false_path write_clk to output_reg_ffs} $fifo_inst]
            set_false_path -from $write_clk -to $output_reg_ffs
            axis_async_fifo_dbg [format {048 fifo=%s after set_false_path write_clk to output_reg_ffs} $fifo_inst]
        }
        axis_async_fifo_dbg [format {049 fifo=%s after output_reg_ffs if} $fifo_inst]

        # frame FIFO pointer update synchronization
        axis_async_fifo_dbg [format {050 fifo=%s before set update_ffs} $fifo_inst]
        set update_ffs [get_cells -quiet -hier -regexp ".*/wr_ptr_update(_ack)?_sync\[123\]_reg_reg" -filter "PARENT == $fifo_inst"]
        axis_async_fifo_dbg [format {051 fifo=%s after set update_ffs count=%d} $fifo_inst [llength $update_ffs]]

        axis_async_fifo_dbg [format {052 fifo=%s before update_ffs if} $fifo_inst]
        if {[llength $update_ffs]} {
            axis_async_fifo_dbg [format {053 fifo=%s before set_property ASYNC_REG update_ffs} $fifo_inst]
            set_property ASYNC_REG TRUE $update_ffs
            axis_async_fifo_dbg [format {054 fifo=%s after set_property ASYNC_REG update_ffs} $fifo_inst]

            axis_async_fifo_dbg [format {055 fifo=%s before set_max_delay wr_ptr_update to wr_ptr_update_sync1} $fifo_inst]
            set_max_delay -from [get_cells $fifo_inst/wr_ptr_update_reg_reg] -to [get_cells $fifo_inst/wr_ptr_update_sync1_reg_reg] -datapath_only $write_clk_period
            axis_async_fifo_dbg [format {056 fifo=%s after set_max_delay wr_ptr_update to wr_ptr_update_sync1} $fifo_inst]

            axis_async_fifo_dbg [format {057 fifo=%s before set_max_delay wr_ptr_update_sync3 to wr_ptr_update_ack_sync1} $fifo_inst]
            set_max_delay -from [get_cells $fifo_inst/wr_ptr_update_sync3_reg_reg] -to [get_cells $fifo_inst/wr_ptr_update_ack_sync1_reg_reg] -datapath_only $read_clk_period
            axis_async_fifo_dbg [format {058 fifo=%s after set_max_delay wr_ptr_update_sync3 to wr_ptr_update_ack_sync1} $fifo_inst]
        }
        axis_async_fifo_dbg [format {059 fifo=%s after update_ffs if} $fifo_inst]

        # status synchronization
        axis_async_fifo_dbg [format {060 fifo=%s before status synchronization foreach} $fifo_inst]
        foreach i {overflow bad_frame good_frame} {
            axis_async_fifo_dbg [format {061 fifo=%s status=%s before set status_sync_regs} $fifo_inst $i]
            set status_sync_regs [get_cells -quiet -hier -regexp ".*/${i}_sync\[123\]_reg_reg" -filter "PARENT == $fifo_inst"]
            axis_async_fifo_dbg [format {062 fifo=%s status=%s after set status_sync_regs count=%d} $fifo_inst $i [llength $status_sync_regs]]

            axis_async_fifo_dbg [format {063 fifo=%s status=%s before status_sync_regs if} $fifo_inst $i]
            if {[llength $status_sync_regs]} {
                axis_async_fifo_dbg [format {064 fifo=%s status=%s before set_property ASYNC_REG status_sync_regs} $fifo_inst $i]
                set_property ASYNC_REG TRUE $status_sync_regs
                axis_async_fifo_dbg [format {065 fifo=%s status=%s after set_property ASYNC_REG status_sync_regs} $fifo_inst $i]

                axis_async_fifo_dbg [format {066 fifo=%s status=%s before set_max_delay sync1 to sync2} $fifo_inst $i]
                set_max_delay -from [get_cells $fifo_inst/${i}_sync1_reg_reg] -to [get_cells $fifo_inst/${i}_sync2_reg_reg] -datapath_only $read_clk_period
                axis_async_fifo_dbg [format {067 fifo=%s status=%s after set_max_delay sync1 to sync2} $fifo_inst $i]
            }
            axis_async_fifo_dbg [format {068 fifo=%s status=%s after status_sync_regs if} $fifo_inst $i]
        }
        axis_async_fifo_dbg [format {069 fifo=%s after status synchronization foreach} $fifo_inst]

        # CDC-6 warning is not applicable since this bus is Gray coded
        axis_async_fifo_dbg [format {070 fifo=%s before create_waiver CDC-6 read pointer} $fifo_inst]
        create_waiver -type CDC -id {CDC-6} -user "axis_async_fifo"\
        -desc "The CDC-6 warning is waived for the read pointer in axis_async_fifo, since it is Gray coded." \
        -from [get_pins "$fifo_inst/rd_ptr_reg_reg[*]/* $fifo_inst/rd_ptr_gray_reg_reg[*]/*"] -to [get_pins $fifo_inst/rd_ptr_gray_sync1_reg_reg[*]/*]
        axis_async_fifo_dbg [format {071 fifo=%s after create_waiver CDC-6 read pointer} $fifo_inst]

        axis_async_fifo_dbg [format {072 fifo=%s before create_waiver CDC-6 write pointer} $fifo_inst]
        create_waiver -type CDC -id {CDC-6} -user "axis_async_fifo"\
        -desc "The CDC-6 warning is waived for the write pointer in axis_async_fifo, since it is Gray coded." \
        -from [get_pins -quiet "$fifo_inst/wr_ptr_reg_reg[*]/* $fifo_inst/wr_ptr_gray_reg_reg[*]/* $fifo_inst/wr_ptr_sync_gray_reg_reg[*]/*"] -to [get_pins $fifo_inst/wr_ptr_gray_sync1_reg_reg[*]/*]
        axis_async_fifo_dbg [format {073 fifo=%s after create_waiver CDC-6 write pointer} $fifo_inst]

        # When used as a frame FIFO, Vivado incorrectly identifies the write pointer gating as being
        # a clock-enable CDC structure
        axis_async_fifo_dbg [format {074 fifo=%s before create_waiver CDC-15 write pointer} $fifo_inst]
        create_waiver -type CDC -id {CDC-15} -user "axis_async_fifo"\
        -desc "The CDC-15 warning is waived for the write pointer in axis_async_fifo, since it is Gray coded." \
        -from [get_pins -quiet "$fifo_inst/wr_ptr_reg_reg[*]/* $fifo_inst/wr_ptr_gray_reg_reg[*]/* $fifo_inst/wr_ptr_sync_gray_reg_reg[*]/*"] -to [get_pins $fifo_inst/wr_ptr_gray_sync1_reg_reg[*]/*]
        axis_async_fifo_dbg [format {075 fifo=%s after create_waiver CDC-15 write pointer} $fifo_inst]

        axis_async_fifo_dbg [format {076 fifo=%s end of catch body} $fifo_inst]
    } errorMessage] } {
        axis_async_fifo_dbg [format {077 fifo=%s catch handler entered} $fifo_inst]
        send_msg_id {AXIS 1-1} {CRITICAL WARNING} "axis_async_fifo instance $fifo_inst raised the following error:\n$errorMessage"
        axis_async_fifo_dbg [format {078 fifo=%s catch handler finished} $fifo_inst]
    }

    axis_async_fifo_dbg [format {079 fifo=%s after catch block} $fifo_inst]
}

axis_async_fifo_dbg {080 after foreach axis_async_fifo}
