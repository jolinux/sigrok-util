-- SmartScope protocol dissector for Wireshark
--
-- Copyright (C) 2015 Marcus Comstedt <marcus@mc.pp.se>
--
-- based on the Logic16 dissector, which is
--   Copyright (C) 2015 Stefan Bruens <stefan.bruens@rwth-aachen.de>
--   based on the LWLA dissector, which is
--     Copyright (C) 2014 Daniel Elstner <daniel.kitta@gmail.com>
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses/>.

-- Usage: wireshark -X lua_script:labnation-smartscope-dissector.lua
--
-- Create custom protocol for the LabNation SmartScope analyzer.
p_smartscope = Proto("SmartScope", "LabNation SmartScope USB Protocol")

-- Referenced USB URB dissector fields.
local f_urb_type = Field.new("usb.urb_type")
local f_transfer_type = Field.new("usb.transfer_type")
local f_endpoint = Field.new("usb.endpoint_number.endpoint")
local f_direction = Field.new("usb.endpoint_number.direction")

-- Header values
local headers = {
    [0xC0] = "Command",
    [0xAD] = "Answer Dude",
}

-- Commands
local commands = {
   [0x01] = "PIC_VERSION",
   [0x02] = "PIC_WRITE",
   [0x03] = "PIC_READ",
   [0x04] = "PIC_RESET",
   [0x05] = "PIC_BOOTLOADER",
   [0x06] = "EEPROM_READ",
   [0x07] = "EEPROM_WRITE",
   [0x08] = "FLASH_ROM_READ",
   [0x09] = "FLASH_ROM_WRITE",
   [0x0a] = "I2C_WRITE",
   [0x0b] = "I2C_READ",
   [0x0c] = "PROGRAM_FPGA_START",
   [0x0d] = "PROGRAM_FPGA_END",
   [0x0e] = "I2C_WRITE_START",
   [0x0f] = "I2C_WRITE_BULK",
   [0x10] = "I2C_WRITE_STOP",
}

-- Addresses
local pic_addresses = {
   [0x00] = "FORCE_STREAMING",
}

local i2c_addresses = {
   [0x0C] = "SETTINGS",
   [0x0D] = "ROM",
   [0x0E] = "AWG",
}

local settings_addresses = {
   [0] = "STROBE_UPDATE",
   [1] = "SPI_ADDRESS",
   [2] = "SPI_WRITE_VALUE",
   [3] = "DIVIDER_MULTIPLIER",
   [4] = "CHA_YOFFSET_VOLTAGE",
   [5] = "CHB_YOFFSET_VOLTAGE",
   [6] = "TRIGGER_PWM",
   [7] = "TRIGGER_LEVEL",
   [8] = "TRIGGER_THRESHOLD",
   [9] = "TRIGGER_MODE",
   [10] = "TRIGGER_WIDTH",
   [11] = "INPUT_DECIMATION",
   [12] = "ACQUISITION_DEPTH",
   [13] = "TRIGGERHOLDOFF_B0",
   [14] = "TRIGGERHOLDOFF_B1",
   [15] = "TRIGGERHOLDOFF_B2",
   [16] = "TRIGGERHOLDOFF_B3",
   [17] = "VIEW_DECIMATION",
   [18] = "VIEW_OFFSET_B0",
   [19] = "VIEW_OFFSET_B1",
   [20] = "VIEW_OFFSET_B2",
   [21] = "VIEW_ACQUISITIONS",
   [22] = "VIEW_BURSTS",
   [23] = "VIEW_EXCESS_B0",
   [24] = "VIEW_EXCESS_B1",
   [25] = "DIGITAL_TRIGGER_RISING",
   [26] = "DIGITAL_TRIGGER_FALLING",
   [27] = "DIGITAL_TRIGGER_HIGH",
   [28] = "DIGITAL_TRIGGER_LOW",
   [29] = "DIGITAL_OUT",
   [30] = "AWG_DEBUG",
   [31] = "AWG_DECIMATION",
   [32] = "AWG_SAMPLES_B0",
   [33] = "AWG_SAMPLES_B1",
}

local rom_addresses = {
   [0] = "FW_MSB",
   [1] = "FW_LSB",
   [2] = "FW_GIT0",
   [3] = "FW_GIT1",
   [4] = "FW_GIT2",
   [5] = "FW_GIT3",
   [6] = "SPI_RECEIVED_VALUE",
   [7] = "STROBES",
}

local strobe_numbers = {
   [0] = "GLOBAL_RESET",
   [1] = "INIT_SPI_TRANSFER",
   [2] = "AWG_ENABLE",
   [3] = "LA_ENABLE",
   [4] = "SCOPE_ENABLE",
   [5] = "SCOPE_UPDATE",
   [6] = "FORCE_TRIGGER",
   [7] = "VIEW_UPDATE",
   [8] = "VIEW_SEND_OVERVIEW",
   [9] = "VIEW_SEND_PARTIAL",
   [10] = "ACQ_START",
   [11] = "ACQ_STOP",
   [12] = "CHA_DCCOUPLING",
   [13] = "CHB_DCCOUPLING",
   [14] = "ENABLE_ADC",
   [15] = "OVERFLOW_DETECT",
   [16] = "ENABLE_NEG",
   [17] = "ENABLE_RAM",
   [18] = "DOUT_3V_5V",
   [19] = "EN_OPAMP_B",
   [20] = "AWG_DEBUG",
   [21] = "DIGI_DEBUG",
   [22] = "ROLL",
   [23] = "LA_CHANNEL",
}

-- Magic values
local magic = {
    [0x4C4E] = "LabNation",
}


-- Create the fields exhibited by the protocol.
p_smartscope.fields.header   = ProtoField.uint8("smartscope.header", "Header", base.HEX_DEC, headers)
p_smartscope.fields.command  = ProtoField.uint8("smartscope.cmd", "Command ID", base.HEX_DEC, commands)
p_smartscope.fields.pic_version = ProtoField.string("smartscope.pic_version", "PIC version")
p_smartscope.fields.pic_address = ProtoField.uint8("smartscope.pic_address", "PIC address", base.HEX, pic_addresses)
p_smartscope.fields.pic_length = ProtoField.uint8("smartscope.pic_length", "PIC length", base.HEX_DEC)
p_smartscope.fields.pic_data   = ProtoField.bytes("smartscope.pic_data", "PIC data")
p_smartscope.fields.eeprom_address = ProtoField.uint8("smartscope.eeprom_address", "EEPROM address", base.HEX)
p_smartscope.fields.eeprom_length = ProtoField.uint8("smartscope.eeprom_length", "EEPROM length", base.HEX_DEC)
p_smartscope.fields.eeprom_data   = ProtoField.bytes("smartscope.eeprom_data", "EEPROM data")
p_smartscope.fields.flash_rom_address = ProtoField.uint16("smartscope.flash_rom_address", "Flash ROM address", base.HEX)
p_smartscope.fields.flash_rom_length = ProtoField.uint8("smartscope.flash_rom_length", "Flash ROM length", base.HEX_DEC)
p_smartscope.fields.flash_rom_data   = ProtoField.bytes("smartscope.flash_rom_data", "Flash ROM data")
p_smartscope.fields.i2c_write_length = ProtoField.uint8("smartscope.i2c_write_length", "I2C write length")
p_smartscope.fields.i2c_write_rawdata = ProtoField.bytes("smartscope.i2c_write_rawdata", "Raw I2C write data")
p_smartscope.fields.i2c_write_slave_address = ProtoField.uint8("smartscope.i2c_write_slave_address", "I2C write slave address", base.HEX_DEC, i2c_addresses, 0xfe)
p_smartscope.fields.i2c_write_mode = ProtoField.bool("smartscope.i2c_write_mode", "I2C write mode", 8, {"READ", "WRITE"}, 0x01)
p_smartscope.fields.settings_subaddress = ProtoField.uint8("smartscope.settings_subaddress", "I2C subaddress (SETTINGS)", base.HEX, settings_addresses)
p_smartscope.fields.rom_subaddress = ProtoField.uint8("smartscope.rom_subaddress", "I2C subaddress (ROM)", base.HEX, rom_addresses)
p_smartscope.fields.awg_subaddress = ProtoField.uint8("smartscope.awg_subaddress", "I2C subaddress (AWG)", base.HEX)
p_smartscope.fields.strobe_number = ProtoField.uint8("smartscope.strobe_number", "Strobe number", base.DEC, strobe_numbers, 0xfe)
p_smartscope.fields.strobe_value = ProtoField.uint8("smartscope.strobe_value", "Strobe value", base.DEC, nil, 0x01)
p_smartscope.fields.i2c_write_payload = ProtoField.bytes("smartscope.i2c_write_payload", "I2C write payload")
p_smartscope.fields.i2c_read_slave_address = ProtoField.uint8("smartscope.i2c_read_slave_address", "I2C read slave address", base.HEX_DEC, i2c_addresses)
p_smartscope.fields.i2c_read_length = ProtoField.uint8("smartscope.i2c_read_length", "I2C read length")
p_smartscope.fields.i2c_read_payload = ProtoField.bytes("smartscope.i2c_read_payload", "I2C read payload")
p_smartscope.fields.fpga_packets = ProtoField.uint16("smartscope.fpga_packets", "FPGA packet count", base.HEX_DEC)
p_smartscope.fields.fpga_data = ProtoField.bytes("smartscope.fpga_data", "FPGA bitstream data")
p_smartscope.fields.rawdata   = ProtoField.bytes("smartscope.rawdata", "Raw Message Data")

p_smartscope.fields.magic = ProtoField.uint16("smartscope.magic", "Magic", base.HEX_DEC, magic)
p_smartscope.fields.header_offset = ProtoField.uint8("smartscope.header_offset", "Header offset", base.HEX_DEC)
p_smartscope.fields.bytes_per_burst = ProtoField.uint8("smartscope.bytes_per_burst", "Bytes per burst", base.HEX_DEC)
p_smartscope.fields.number_of_payload_bursts = ProtoField.uint16("smartscope.number_of_payload_bursts", "Number of payload bursts", base.HEX_DEC)
p_smartscope.fields.package_offset = ProtoField.uint16("smartscope.package_offset", "Package offset", base.HEX_DEC)
p_smartscope.fields.acquiring = ProtoField.bool("smartscope.acquiring", "Acquiring", 8, nil, 0x01)
p_smartscope.fields.overview_buffer = ProtoField.bool("smartscope.overview_buffer", "Overview Buffer", 8, nil, 0x02)
p_smartscope.fields.last_acquisition = ProtoField.bool("smartscope.last_acquisition", "Last Acquisition", 8, nil, 0x04)
p_smartscope.fields.rolling = ProtoField.bool("smartscope.rolling", "Rolling", 8, nil, 0x08)
p_smartscope.fields.timed_out = ProtoField.bool("smartscope.timed_out", "Timed Out", 8, nil, 0x10)
p_smartscope.fields.awaiting_trigger = ProtoField.bool("smartscope.awaiting_trigger", "Awaiting Trigger", 8, nil, 0x20)
p_smartscope.fields.armed = ProtoField.bool("smartscope.armed", "Armed", 8, nil, 0x40)
p_smartscope.fields.full_acquisition_dump = ProtoField.bool("smartscope.full_acquisition_dump", "Full Acquisition Dump", 8, nil, 0x80)
p_smartscope.fields.acquisition_id = ProtoField.uint8("smartscope.acquisition_id", "Acquisition ID", base.HEX_DEC)
p_smartscope.fields.header_trigger_level = ProtoField.uint8("smartscope.header.trigger_level", "Trigger Level", base.HEX_DEC)
p_smartscope.fields.header_trigger_mode = ProtoField.uint8("smartscope.header.trigger_mode", "Trigger Mode", base.HEX_DEC)
p_smartscope.fields.header_trigger_width = ProtoField.uint8("smartscope.header.trigger_width", "Trigger Width", base.HEX_DEC)
p_smartscope.fields.header_trigger_holdoff = ProtoField.uint32("smartscope.header.trigger_holdoff", "Trigger Holdoff", base.HEX_DEC)
p_smartscope.fields.header_cha_yoffset_voltage = ProtoField.uint8("smartscope.header.cha_yoffset_voltage", "Channel A Y-Offset Voltage", base.HEX_DEC)
p_smartscope.fields.header_chb_yoffset_voltage = ProtoField.uint8("smartscope.header.chb_yoffset_voltage", "Channel B Y-Offset Voltage", base.HEX_DEC)
p_smartscope.fields.header_divider_multiplier = ProtoField.uint8("smartscope.header.divider_multiplier", "Divider Multiplier", base.HEX_DEC)
p_smartscope.fields.header_input_decimation = ProtoField.uint8("smartscope.header.input_decimation", "Input Decimation", base.HEX_DEC)
p_smartscope.fields.header_trigger_threshold = ProtoField.uint8("smartscope.header.trigger_threshold", "Trigger Threshold", base.HEX_DEC)
p_smartscope.fields.header_trigger_pwm = ProtoField.uint8("smartscope.header.trigger_pwm", "Trigger PWM", base.HEX_DEC)
p_smartscope.fields.header_trigger_rising = ProtoField.uint8("smartscope.header.trigger_rising", "Trigger Rising", base.HEX_DEC)
p_smartscope.fields.header_trigger_falling = ProtoField.uint8("smartscope.header.trigger_falling", "Trigger Falling", base.HEX_DEC)
p_smartscope.fields.header_trigger_high = ProtoField.uint8("smartscope.header.trigger_high", "Trigger High", base.HEX_DEC)
p_smartscope.fields.header_trigger_low = ProtoField.uint8("smartscope.header.trigger_low", "Trigger Low", base.HEX_DEC)
p_smartscope.fields.header_acquisition_depth = ProtoField.uint8("smartscope.header.acquisition_depth", "Acquisition Depth", base.HEX_DEC)
p_smartscope.fields.header_view_decimation = ProtoField.uint8("smartscope.header.view_decimation", "View Decimation", base.HEX_DEC)
p_smartscope.fields.header_view_offset = ProtoField.uint24("smartscope.header.view_offset", "View Offset", base.HEX_DEC)
p_smartscope.fields.header_view_acquisitions = ProtoField.uint8("smartscope.header.view_acquisitions", "View Acquisitions", base.HEX_DEC)
p_smartscope.fields.header_view_bursts = ProtoField.uint8("smartscope.header.view_bursts", "View Bursts", base.HEX_DEC)
p_smartscope.fields.header_view_excess = ProtoField.uint16("smartscope.header.view_excess", "View Excess", base.HEX_DEC)
p_smartscope.fields.header_awg_enable = ProtoField.bool("smartscope.header.awg_enable", "AWG Enable", 8, nil, 0x01)
p_smartscope.fields.header_la_enable = ProtoField.bool("smartscope.header.la_enable", "LA Enable", 8, nil, 0x02)
p_smartscope.fields.header_cha_coupling = ProtoField.bool("smartscope.header.cha_coupling", "Channel A Coupling", 8, {"DC", "AC"}, 0x04)
p_smartscope.fields.header_chb_coupling = ProtoField.bool("smartscope.header.chb_coupling", "Channel B Coupling", 8, {"DC", "AC"}, 0x08)
p_smartscope.fields.header_digi_debug = ProtoField.bool("smartscope.header.digi_debug", "Digi Debug", 8, nil, 0x10)
p_smartscope.fields.header_roll = ProtoField.bool("smartscope.header.rolling", "Rolling", 8, nil, 0x20)
p_smartscope.fields.header_la_channel = ProtoField.bool("smartscope.header.la_channel", "LA Channel", 8, {"Channel B", "Channel A"}, 0x40)

p_smartscope.fields.acq_data = ProtoField.bytes("smartscope.acquisition_data", "Acquisition data")


-- State variables
local pktFpgaData
local fpgaDataCount
local pktAcqData
local acqDataCount

-- Dissect control command messages.
local function dissect_command(range, pinfo, tree, command)
    pinfo.cols.info = string.format("-> [%d]: %s", command, commands[command] or "???")
    if command == 2 then -- pic write
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.pic_address, range(0,1))
        tree:add(p_smartscope.fields.pic_length, range(1,1))
        tree:add(p_smartscope.fields.pic_data, range(2,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" %s len=%d", (pic_addresses[addr] or string.format("0x%02X", addr)), range(1,1):uint()))
    elseif command == 3 then -- pic read
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.pic_address, range(0,1))
        tree:add(p_smartscope.fields.pic_length, range(1,1))
	pinfo.cols.info:append(string.format(" %s len=%d", (pic_addresses[addr] or string.format("0x%02X", addr)), range(1,1):uint()))
    elseif command == 6 then -- eeprom read
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.eeprom_address, range(0,1))
        tree:add(p_smartscope.fields.eeprom_length, range(1,1))
	pinfo.cols.info:append(string.format(" 0x%02X len=%d", addr, range(1,1):uint()))
    elseif command == 7 then -- eeprom write
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.eeprom_address, range(0,1))
        tree:add(p_smartscope.fields.eeprom_length, range(1,1))
        tree:add(p_smartscope.fields.eeprom_data, range(2,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" 0x%02X len=%d", addr, range(1,1):uint()))
    elseif command == 8 then -- flash rom read
        local addr = range(0,1):uint()+256*range(2,1):uint()
        tree:add(p_smartscope.fields.flash_rom_address, range(0,3), addr)
        tree:add(p_smartscope.fields.flash_rom_length, range(1,1))
	pinfo.cols.info:append(string.format(" 0x%03X len=%d", addr, range(1,1):uint()))
    elseif command == 9 then -- flash rom write
        local addr = range(0,1):uint()+256*range(2,1):uint()
        tree:add(p_smartscope.fields.flash_rom_address, range(0,3), addr)
        tree:add(p_smartscope.fields.flash_rom_length, range(1,1))
        tree:add(p_smartscope.fields.flash_rom_data, range(3,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" 0x%03X len=%d", addr, range(1,1):uint()))
    elseif command == 10 or command == 14 then -- i2c write / i2c write start
        tree:add(p_smartscope.fields.i2c_write_length, range(0,1))
	tree:add(p_smartscope.fields.i2c_write_rawdata, range(1))
	local len = range(0,1):uint()
        if len > 0 then
	   local slave = bit.rshift(range(1,1):uint(), 1)
	   tree:add(p_smartscope.fields.i2c_write_slave_address, range(1,1))
	   tree:add(p_smartscope.fields.i2c_write_mode, range(1,1))
	   if len > 1 then
	      local subaddress = range(2,1):uint()
	      local payload = len > 2 and range(3)
	      if slave == 12 then -- settings
		 tree:add(p_smartscope.fields.settings_subaddress, range(2,1))
		 pinfo.cols.info:append(" SETTINGS["..(settings_addresses[subaddress] or "???").."]")
	      elseif slave == 13 then -- rom
		 tree:add(p_smartscope.fields.rom_subaddress, range(2,1))
		 pinfo.cols.info:append(" ROM["..(rom_addresses[subaddress] or "???").."]")
	      elseif slave == 14 then -- awg
		 tree:add(p_smartscope.fields.awg_subaddress, range(2,1))
		 pinfo.cols.info:append(string.format(" AWG[%d]", subaddress))
	      else
		 payload = range(2)
	      end
	      if payload and payload:len() == 1 and slave == 12 and subaddress == 0 then
		 local strobe = payload(0,1):uint()
		 local value = bit.band(strobe, 1)
		 strobe = bit.rshift(strobe, 1)
		 tree:add(p_smartscope.fields.strobe_number, payload(0,1))
		 tree:add(p_smartscope.fields.strobe_value, payload(0,1))
		 pinfo.cols.info:append(string.format(" STROBE[%s] = %d", (strobe_numbers[strobe] or string.format("%d", strobe)), value))
	      elseif payload then
		 tree:add(p_smartscope.fields.i2c_write_payload, payload)
		 pinfo.cols.info:append(string.format(" len=%d", payload:len()))
	      end
	   end
        end
    elseif command == 11 then -- i2c read
        local slave = range(0,1):uint()
        tree:add(p_smartscope.fields.i2c_read_slave_address, range(0,1))
        tree:add(p_smartscope.fields.i2c_read_length, range(1,1))
	if i2c_addresses[slave] then
	   pinfo.cols.info:append(string.format(" %s", i2c_addresses[slave]))
	end
	pinfo.cols.info:append(string.format(" len=%d", range(1,1):uint()))
    elseif command == 12 then -- program fpga start
        tree:add(p_smartscope.fields.fpga_packets, range(0,2))
        fpgaDataCount = range(0,2):uint()*32
    elseif command == 15 then -- i2c write bulk
        tree:add(p_smartscope.fields.i2c_write_length, range(0,1))
	tree:add(p_smartscope.fields.i2c_write_rawdata, range(1))
	local len = range(0,1):uint()
        if len > 0 then
	   tree:add(p_smartscope.fields.i2c_write_payload, range(1,len))
	   pinfo.cols.info:append(string.format(" len=%d", len))
	end
    elseif command == 16 then -- i2c write stop
        tree:add(p_smartscope.fields.i2c_write_length, range(0,1))
	local len = range(0,1):uint()
        if len > 0 then
	   pinfo.cols.info:append(string.format(" len=%d", len))
	end
    end
end

-- Dissect answers to control command messages.
local function dissect_answer(range, pinfo, tree, command)
    pinfo.cols.info = string.format("<- [%d]: %s", command, commands[command] or "???")
    if command == 1 then -- pic version
        local version = string.format("%d.%d.%d", range(4,1):uint(), range(3,1):uint(), range(2,1):uint())
        tree:add(p_smartscope.fields.pic_version, range(2,3), version)
	pinfo.cols.info:append(' "' .. version .. '"')
    elseif command == 3 then -- pic read
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.pic_address, range(0,1))
        tree:add(p_smartscope.fields.pic_length, range(1,1))
        tree:add(p_smartscope.fields.pic_data, range(2,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" %s len=%d", (pic_addresses[addr] or string.format("0x%02X", addr)), range(1,1):uint()))
    elseif command == 6 then -- eeprom read
        local addr = range(0,1):uint()
        tree:add(p_smartscope.fields.eeprom_address, range(0,1))
        tree:add(p_smartscope.fields.eeprom_length, range(1,1))
        tree:add(p_smartscope.fields.eeprom_data, range(2,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" 0x%02X len=%d", addr, range(1,1):uint()))
    elseif command == 8 then -- flash rom read
        local addr = range(0,1):uint()+256*bit.band(range(2,1):uint(),0xf)
        tree:add(p_smartscope.fields.flash_rom_address, range(0,3), addr)
        tree:add(p_smartscope.fields.flash_rom_length, range(1,1))
        tree:add(p_smartscope.fields.flash_rom_data, range(3,range(1,1):uint()))
	pinfo.cols.info:append(string.format(" 0x%03X len=%d", addr, range(1,1):uint()))
    elseif command == 11 then -- i2c read
        local slave = range(0,1):uint()
        tree:add(p_smartscope.fields.i2c_read_slave_address, range(0,1))
        tree:add(p_smartscope.fields.i2c_read_length, range(1,1))
	if i2c_addresses[slave] then
	   pinfo.cols.info:append(string.format(" %s", i2c_addresses[slave]))
	end
	local len = range(1,1):uint()
	tree:add(p_smartscope.fields.i2c_read_payload, range(2,len))
	pinfo.cols.info:append(string.format(" len=%d", len))
    end
end

-- Dissect buld data header.
local function dissect_dataheader(range, pinfo, tree)
   local subtree = tree:add(range, "Header")
   subtree:add(p_smartscope.fields.header_trigger_level, range(0,1))
   subtree:add(p_smartscope.fields.header_trigger_mode, range(1,1))
   subtree:add(p_smartscope.fields.header_trigger_width, range(2,1))
   subtree:add_le(p_smartscope.fields.header_trigger_holdoff, range(3,4))
   subtree:add(p_smartscope.fields.header_cha_yoffset_voltage, range(7,1))
   subtree:add(p_smartscope.fields.header_chb_yoffset_voltage, range(8,1))
   subtree:add(p_smartscope.fields.header_divider_multiplier, range(9,1))
   subtree:add(p_smartscope.fields.header_input_decimation, range(10,1))
   subtree:add(p_smartscope.fields.header_trigger_threshold, range(11,1))
   subtree:add(p_smartscope.fields.header_trigger_pwm, range(12,1))
   subtree:add(p_smartscope.fields.header_trigger_rising, range(13,1))
   subtree:add(p_smartscope.fields.header_trigger_falling, range(14,1))
   subtree:add(p_smartscope.fields.header_trigger_high, range(15,1))
   subtree:add(p_smartscope.fields.header_trigger_low, range(16,1))
   subtree:add(p_smartscope.fields.header_acquisition_depth, range(17,1))
   subtree:add(p_smartscope.fields.header_view_decimation, range(18,1))
   subtree:add_le(p_smartscope.fields.header_view_offset, range(19,3))
   subtree:add(p_smartscope.fields.header_view_acquisitions, range(22,1))
   subtree:add(p_smartscope.fields.header_view_bursts, range(23,1))
   subtree:add_le(p_smartscope.fields.header_view_excess, range(24,2))
   subtree:add(p_smartscope.fields.header_awg_enable, range(26,1))
   subtree:add(p_smartscope.fields.header_la_enable, range(26,1))
   subtree:add(p_smartscope.fields.header_cha_coupling, range(26,1))
   subtree:add(p_smartscope.fields.header_chb_coupling, range(26,1))
   subtree:add(p_smartscope.fields.header_digi_debug, range(26,1))
   subtree:add(p_smartscope.fields.header_roll, range(26,1))
   subtree:add(p_smartscope.fields.header_la_channel, range(26,1))
end

-- Dissect bulk data.
local function dissect_data(range, pinfo, tree)
   tree:add(p_smartscope.fields.magic, range(0,2))
   if (range(0,2):uint() ~= 0x4C4E) then
      return
   end
   pinfo.cols.info = string.format("<- Acquisition header")
   tree:add(p_smartscope.fields.header_offset, range(2,1))
   tree:add(p_smartscope.fields.bytes_per_burst, range(3,1))
   tree:add_le(p_smartscope.fields.number_of_payload_bursts, range(4,2))
   tree:add_le(p_smartscope.fields.package_offset, range(6,2))
   tree:add(p_smartscope.fields.acquiring, range(10,1))
   tree:add(p_smartscope.fields.overview_buffer, range(10,1))
   tree:add(p_smartscope.fields.last_acquisition, range(10,1))
   tree:add(p_smartscope.fields.rolling, range(10,1))
   tree:add(p_smartscope.fields.timed_out, range(10,1))
   tree:add(p_smartscope.fields.awaiting_trigger, range(10,1))
   tree:add(p_smartscope.fields.armed, range(10,1))
   tree:add(p_smartscope.fields.full_acquisition_dump, range(10,1))
   tree:add(p_smartscope.fields.acquisition_id, range(11,1))
   dissect_dataheader(range(range(2,1):uint(), 27), pinfo, tree)
   pinfo.cols.info:append(string.format(" id=0x%02x", range(11,1):uint()))
   acqDataCount = range(3,1):uint() * range(4,2):le_uint()
   if (bit.band(range(10,1):uint(), 0x02) ~= 0) then
      pinfo.cols.info:append(" (overview buffer)")
      acqDataCount = 4096
   elseif (bit.band(range(10,1):uint(), 0x80) ~= 0) then
      pinfo.cols.info:append(string.format(" (full acquisition dump offset=%d)", range(6,2):le_uint()))
   end
end

-- Main dissector function.
function p_smartscope.dissector(tvb, pinfo, tree)
    local transfer_type = tonumber(tostring(f_transfer_type()))

    -- Bulk transfers only.
    if transfer_type == 3 then
        local urb_type = tonumber(tostring(f_urb_type()))
        local endpoint = tonumber(tostring(f_endpoint()))
        local direction = tonumber(tostring(f_direction()))

        -- Payload-carrying packets only.
        if (urb_type == 67 and endpoint == 1 and direction == 1)     -- 'C' - Complete
            or (urb_type == 83 and endpoint == 2 and direction == 0) -- 'S' - Submit
            or (urb_type == 67 and endpoint == 3 and direction == 1) -- 'C' - Complete
        then
            pinfo.cols.protocol = p_smartscope.name

            local subtree = tree:add(p_smartscope, tvb(), "SmartScope")
            subtree:add(p_smartscope.fields.rawdata, tvb())

	    if endpoint == 1 and direction == 1 then
	        if pktAcqData[pinfo.number] == nil then
		    pktAcqData[pinfo.number] = (acqDataCount > 0)
		    if acqDataCount > tvb:len() then
		       acqDataCount = acqDataCount - tvb:len()
		    else
		       acqDataCount = 0
		    end
		end

		if pktAcqData[pinfo.number] == true then
		    subtree:add(p_smartscope.fields.acq_data, tvb())
		    pinfo.cols.info = string.format("<- Acquisition data (%d bytes)", tvb:len())
		    return
		end
	    end

	    if endpoint == 2 and direction == 0 then
	        if pktFpgaData[pinfo.number] == nil then
		    pktFpgaData[pinfo.number] = (fpgaDataCount > 0)
		    if fpgaDataCount > tvb:len() then
		       fpgaDataCount = fpgaDataCount - tvb:len()
		    else
		       fpgaDataCount = 0
		    end
		end

		if pktFpgaData[pinfo.number] == true then
		    subtree:add(p_smartscope.fields.fpga_data, tvb())
		    pinfo.cols.info = string.format("-> FPGA bitstream data (%d bytes)", tvb:len())
		    return
		end

	    end

	    if endpoint == 1 then
	       dissect_data(tvb, pinfo, subtree)
	       return
	    end

	    local header = tvb(0,1):uint()
	    subtree:add(p_smartscope.fields.header, tvb(0,1))
	    local command = tvb(1,1):uint()
	    subtree:add(p_smartscope.fields.command, tvb(1,1))
	    if endpoint == 2 and header == 0xc0 then
	       dissect_command(tvb(2), pinfo, subtree, command)
	    elseif endpoint == 3 and header == 0xad then
	       dissect_answer(tvb(2), pinfo, subtree, command)
	    end
	end
    end
end

-- Register SmartScope protocol dissector during initialization.
function p_smartscope.init()

    pktFpgaData = {}
    fpgaDataCount = 0
    pktAcqData = {}
    acqDataCount = 0

    local usb_product_dissectors = DissectorTable.get("usb.product")

    -- Dissection by vendor+product ID requires that Wireshark can get the
    -- the device descriptor.  Making a USB device available inside a VM
    -- will make it inaccessible from Linux, so Wireshark cannot fetch the
    -- descriptor by itself.  However, it is sufficient if the guest requests
    -- the descriptor once while Wireshark is capturing.
    usb_product_dissectors:add(0x04d8f4b5, p_smartscope)
end
