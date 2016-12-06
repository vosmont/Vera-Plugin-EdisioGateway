--[[
  This file is part of the plugin Edisio Gateway.
  https://github.com/vosmont/Vera-Plugin-EdisioGateway
  Copyright (c) 2016 Vincent OSMONT
  This code is released under the MIT License, see LICENSE.
--]]

module( "L_EdisioGateway1", package.seeall )

-- Load libraries
local status, json = pcall( require, "dkjson" )
if ( type( json ) ~= "table" ) then
	-- UI5
	json = require( "json" )
end


-- **************************************************
-- Plugin constants
-- **************************************************

_NAME = "EdisioGateway"
_DESCRIPTION = "edisio gateway for the Vera"
_VERSION = "0.7"
_AUTHOR = "vosmont"


-- **************************************************
-- UI compatibility
-- **************************************************

-- Update static JSON file
local function _updateStaticJSONFile( lul_device, pluginName )
	local isUpdated = false
	if ( luup.version_branch ~= 1 ) then
		luup.log( "ERROR - Plugin '" .. pluginName .. "' - checkStaticJSONFile : don't know how to do with this version branch " .. tostring( luup.version_branch ), 1 )
	elseif ( luup.version_major > 5 ) then
		local currentStaticJsonFile = luup.attr_get( "device_json", lul_device )
		local expectedStaticJsonFile = "D_" .. pluginName .. "_UI" .. tostring( luup.version_major ) .. ".json"
		if ( currentStaticJsonFile ~= expectedStaticJsonFile ) then
			luup.attr_set( "device_json", expectedStaticJsonFile, lul_device )
			isUpdated = true
		end
	end
	return isUpdated
end


-- **************************************************
-- Constants
-- **************************************************

-- This table defines all device variables that are used by the plugin
-- Each entry is a table of 4 elements:
-- 1) the service ID
-- 2) the variable name
-- 3) true if the variable is not updated when the value is unchanged
-- 4) variable that is used for the timestamp
local VARIABLE = {
	TEMPERATURE = { "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", true },
	HUMIDITY = { "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", true },
	SWITCH_POWER = { "urn:upnp-org:serviceId:SwitchPower1", "Status", true },
	DIMMER_LEVEL = { "urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", true },
	DIMMER_LEVEL_OLD = { "urn:upnp-org:serviceId:EdisioDevice1", "LoadLevelStatus", true },
	DIMMER_DIRECTION = { "urn:upnp-org:serviceId:EdisioDevice1", "LoadLevelDirection", true },
	DIMMER_STEP = { "urn:upnp-org:serviceId:EdisioDevice1", "DimmingStep", true },
	PULSE_MODE = { "urn:upnp-org:serviceId:EdisioDevice1", "PulseMode", true },
	IGNORE_BURST_TIME = { "urn:upnp-org:serviceId:EdisioDevice1", "IgnoreBurstTime", true },
	-- Security
	ARMED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", true },
	TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", false, "LAST_TRIP" },
	ARMED_TRIPPED = { "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", false, "LAST_TRIP" },
	LAST_TRIP = { "urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", true },
	-- Battery
	BATTERY_LEVEL = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", true, "BATTERY_DATE" },
	BATTERY_DATE = { "urn:micasaverde-com:serviceId:HaDevice1", "BatteryDate", true },
	-- IO connection
	IO_DEVICE = { "urn:micasaverde-com:serviceId:HaDevice1", "IODevice", false },
	IO_PORT_PATH = { "urn:micasaverde-com:serviceId:HaDevice1", "IOPortPath", false },
	BAUD = { "urn:micasaverde-org:serviceId:SerialPort1", "baud", false },
	STOP_BITS = { "urn:micasaverde-org:serviceId:SerialPort1", "stopbits", false },
	DATA_BITS = { "urn:micasaverde-org:serviceId:SerialPort1", "databits", false },
	PARITY = { "urn:micasaverde-org:serviceId:SerialPort1", "parity", false },
	
	LIGHT_LEVEL = { "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", false },
	-- Communication failure
	COMM_FAILURE = { "urn:micasaverde-com:serviceId:HaDevice1", "CommFailure", false, "COMM_FAILURE_TIME" },
	COMM_FAILURE_TIME = { "urn:micasaverde-com:serviceId:HaDevice1", "CommFailureTime", true },
	-- Edisio gateway
	PLUGIN_VERSION = { "urn:upnp-org:serviceId:EdisioGateway1", "PluginVersion", true },
	DEBUG_MODE = { "urn:upnp-org:serviceId:EdisioGateway1", "DebugMode", true },
	LAST_DISCOVERED = { "urn:upnp-org:serviceId:EdisioGateway1", "LastDiscovered", true },
	LAST_UPDATE = { "urn:upnp-org:serviceId:EdisioGateway1", "LastUpdate", true },
	POLLING_ENABLED = { "urn:upnp-org:serviceId:EdisioGateway1", "PollingEnabled", true },
	LAST_MESSAGE = { "urn:upnp-org:serviceId:EdisioGateway1", "LastMessage", true },
	LAST_ERROR = { "urn:upnp-org:serviceId:EdisioGateway1", "LastError", true },
	-- Edisio device
	MODEL_ID = { "urn:upnp-org:serviceId:EdisioDevice1", "ModelId", true },
	ASSOCIATION = { "urn:upnp-org:serviceId:EdisioDevice1", "Association", true },
	PRODUCT_ID = { "urn:upnp-org:serviceId:EdisioDevice1", "ProductId", true },
	VARIABLES_GET = { "urn:upnp-org:serviceId:EdisioDevice1", "VariablesGet", true },
	VARIABLES_SET = { "urn:upnp-org:serviceId:EdisioDevice1", "VariablesSet", true }
	--PRODUCT_ID = { "urn:upnp-org:serviceId:EdisioDevice1", "ConfiguredVariable", true },
}

-- Device types
local DEVICE_TYPE = {
	SERIAL_PORT = {
		deviceType = "urn:micasaverde-org:device:SerialPort:1", deviceFile = "D_SerialPort1.xml"
	},
	DOOR_SENSOR = {
		deviceType = "urn:schemas-micasaverde-com:device:DoorSensor:1", deviceFile = "D_DoorSensor1.xml",
		parameters = VARIABLE.ARMED[1] .. "," .. VARIABLE.ARMED[2] .. "=0\n" ..
					VARIABLE.TRIPPED[1] .. "," .. VARIABLE.TRIPPED[2] .. "=0"
	},
	MOTION_SENSOR = {
		deviceType = "urn:schemas-micasaverde-com:device:MotionSensor:1", deviceFile = "D_MotionSensor1.xml",
		parameters = VARIABLE.ARMED[1] .. "," .. VARIABLE.ARMED[2] .. "=0\n" ..
					VARIABLE.TRIPPED[1] .. "," .. VARIABLE.TRIPPED[2] .. "=0"
	},
	BINARY_LIGHT = {
		deviceType = "urn:schemas-upnp-org:device:BinaryLight:1", deviceFile = "D_BinaryLight1.xml",
		parameters = VARIABLE.SWITCH_POWER[1] .. "," .. VARIABLE.SWITCH_POWER[2] .. "=0"
	},
	DIMMABLE_LIGHT = {
		deviceType = "urn:schemas-upnp-org:device:DimmableLight:1", deviceFile = "D_DimmableLight1.xml",
		parameters = VARIABLE.SWITCH_POWER[1] .. "," .. VARIABLE.SWITCH_POWER[2] .. "=0\n" ..
					VARIABLE.DIMMER_LEVEL[1] .. "," .. VARIABLE.DIMMER_LEVEL[2] .. "=0"
	},
	TEMPERATURE_SENSOR = {
		deviceType = "urn:schemas-micasaverde-com:device:TemperatureSensor:1", deviceFile = "D_TemperatureSensor1.xml",
		parameters = VARIABLE.TEMPERATURE[1] .. "," .. VARIABLE.TEMPERATURE[2] .. "=0"
	},
	WINDOW_COVERING = {
		deviceType = "urn:schemas-micasaverde-com:device:WindowCovering:1", deviceFile = "D_WindowCovering1.xml",
		parameters = VARIABLE.DIMMER_LEVEL[1] .. "," .. VARIABLE.DIMMER_LEVEL[2] .. "=0"
	}
}
local function _getDeviceTypeInfos( deviceType )
	for deviceTypeName, deviceTypeInfos in pairs( DEVICE_TYPE ) do
		if ( deviceTypeInfos.deviceType == deviceType ) then
			return deviceTypeInfos
		end
	end
end

local JOB_STATUS = {
	NONE = -1,
	WAITING_TO_START = 0,
	IN_PROGRESS = 1,
	ERROR = 2,
	ABORTED = 3,
	DONE = 4,
	WAITING_FOR_CALLBACK = 5
}

-- Message types
local SYS_MESSAGE_TYPES = {
	BUSY    = 1,
	ERROR   = 2,
	SUCCESS = 4
}

-- **************************************************
-- edisio protocol (White book edisio V1.24)
-- **************************************************

local EDISIO_DEVICES = {
	{
		modelId = 0x01, model = "BUTTON", modelDesc = "Emitter 8 Channels", modelFunction = "On/Off/Pulse/Open/Close", -- (ETC1/ETC4/EBP8)
		deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, isButton = true, isBatteryPowered = true
	}, {
		modelId = 0x07, model = "EMS-100", modelDesc = "Motion sensor", modelFunction = "On/Off/Pulse/Open/Close",
		deviceTypes = { "MOTION_SENSOR" }, isBatteryPowered = true
	}, {
		modelId = 0x08, model = "ETS-100", modelDesc = "Temperature sensor", modelFunction = "Temperature",
		deviceTypes = { "TEMPERATURE_SENSOR" }, isBatteryPowered = true
	}, {
		modelId = 0x09, model = "EDS-100", modelDesc = "Door sensor", modelFunction = "On/Off/Pulse/Open/Close",
		deviceTypes = { "DOOR_SENSOR" }, isBatteryPowered = true
	}, {
		modelId = 0x10, model = "EMR-2000", modelDesc = "Receiver 1 Output", modelFunction = "1x On/Off or Pulse",
		deviceTypes = { "BINARY_LIGHT" }, isReceiver = true
	}, {
		modelId = 0x11, model = "EMV-400", modelDesc = "Receiver 2 Outputs", modelFunction = "2x On/Off or 1x Open/Close",
		deviceTypes = { "BINARY_LIGHT", "WINDOW_COVERING" }, isReceiver = true, nbChannels = 2
	}, {
		modelId = 0x12, model = "EDR-D4", modelDesc = "Receiver 4 outputs", modelFunction = "4x On/Off or Dimer",
		deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, isReceiver = true, nbChannels = 4
	}, {
		modelId = 0x13, model = "EDR-B4", modelDesc = "Receiver 4 outputs", modelFunction = "4x On/Off/Pulse or 2x Open/Close",
		deviceTypes = { "BINARY_LIGHT", "WINDOW_COVERING" }, isReceiver = true, nbChannels = 4
	}, {
		modelId = 0x14, model = "EMSD-300A", modelDesc = "Receiver 1 Output", modelFunction = "1x On/Off or Dimer",
		deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, isReceiver = true
	}, {
		modelId = 0x15, model = "EMSD-300", modelDesc = "Receiver 1 Output", modelFunction = "1x On/Off or Dimer",
		deviceTypes = { "BINARY_LIGHT", "DIMMABLE_LIGHT" }, isReceiver = true
	}, {
		modelId = 0x16, model = "GATEWAY"
	}, {
		modelId = 0x17, model = "EMM-230", modelDesc = "Emitter 2 Channels", modelFunction = "2x On/Off/Pulse/Open/Stop/Close",
		deviceTypes = { "BINARY_LIGHT" }, isButton = true, nbChannels = 2
	}, {
		modelId = 0x18, model = "EMM-100", modelDesc = "Emitter 2 Channels", modelFunction = "2x On/Off/Pulse/Open/Stop/Close",
		deviceTypes = { "BINARY_LIGHT" }, isButton = true, isBatteryPowered = true, nbChannels = 2
	}, {
		modelId = 0x0E, model = "ED-TH-01", modelDesc = "Thermostat", modelFunction = "Thermostat",
		deviceTypes = { "TEMPERATURE_SENSOR" }
	}, {
		modelId = 0x0B, model = "ED-LI-01", modelDesc = "Receiver 1 Output", modelFunction = "1x On/Off",
		deviceTypes = { "BINARY_LIGHT" }, isReceiver = true
	}, {
		modelId = 0x0F, model = "ED-TH-02", modelDesc = "Receiver 1 Output", modelFunction = "1x On/Off Heater/Cooler",
		deviceTypes = {}, isReceiver = true
	}, {
		modelId = 0x0C, model = "ED-TH-03", modelDesc = "Receiver 1 Output FP", modelFunction = "1x Off/Eco/Comfort/Auto (Fil Pilote)",
		deviceTypes = {}, isReceiver = true
	}, {
		modelId = 0x0D, model = "ED-SH-01", modelDesc = "Receiver 2 Outputs", modelFunction = "1x Open/Stop/Close",
		deviceTypes = { "WINDOW_COVERING" }, isReceiver = true
	}
}

local EDISIO_MODEL = {}
local _indexEdisioInfosById = {}
for _, edisioInfos in ipairs( EDISIO_DEVICES ) do
	EDISIO_MODEL[ edisioInfos.model ] = edisioInfos.modelId
	_indexEdisioInfosById[ edisioInfos.modelId ] = edisioInfos
end
local function _getEdisioInfos( modelId )
	local edisioInfos = _indexEdisioInfosById[ modelId ]
	if ( edisioInfos == nil ) then
		warning( "Can not get infos for edisio model " .. number_toHex( modelId ), "getEdisioInfos" )
		edisioInfos = {
			modelId = 0x00, model = "UNKNOWN", modelDesc = "Unknown", modelFunction = "",
			deviceTypes = {}
		}
	end
	return edisioInfos
end


--[[
local EDISIO_PARAMS = {
	dimmer = { { "Minimum light intensity", 1 }, { "Maximum light intensity", 1 } }
	dimmer = "1-Minimum light intensity,1d,3,2-Maximum light intensity,1d,100",
	shutter = ""
	-- variable1_number-variable1_description,variable1_data_type,variable1_value,variable2_number-variable2_description,variable2_data_type,variable2_value,...
	
}
--]]

local EDISIO_COMMAND = {
	NULL            = 0x00,
	ON              = 0x01,
	OFF             = 0x02,
	TOGGLE          = 0x03,
	DIM             = 0x04,
	DIM_UP          = 0x05,
	DIM_DOWN        = 0x06,
	DIM_A           = 0x07,
	DIM_STOP        = 0x08,
	SHUTTER_OPEN    = 0x09,
	SHUTTER_CLOSE   = 0x0A,
	--SHUTTER_CLOSE   = 0x1B, -- (USB dongle V1.0)
	SHUTTER_STOP    = 0x0B,
	RGB             = 0x0C,
	SET_SHORT       = 0x10,
	SET_5S          = 0x11,
	SET_10S         = 0x12,
	STUDY           = 0x16, -- Pairing Request by Gateway
	DEL_BUTTON      = 0x17, -- Reserved for gateway
	DEL_ALL         = 0x18, -- Reserved for gateway
	--DOOR_CLOSE      = 0x19, -- ??
	SET_TEMPERATURE = 0x19, -- Temperature sent by the temperature sensor
	DOOR_OPEN       = 0x1A,
	--BROADCAST_QUERY = 0x1F,
	QUERY_STATUS    = 0x20,
	REPORT_STATUS   = 0x21,
	READ_CUSTOM     = 0x23,
	SAVE_CUSTOM     = 0x24,
	REPORT_CUSTOM   = 0x29,
	SET_SHORT_DIMMER = 0x2C,
	SET_SHORT_SENSOR = 0x2F
}
local function _getEdisioCommandName( CMD )
	for commandName, commandCode in pairs( EDISIO_COMMAND ) do
		if ( commandCode == CMD ) then
			return commandName
		end
	end
	return "UNKNOW(" .. number_toHex( CMD ) .. ")"
end

local STATE = {
	GET_BOOT_CODE = 1,
	GET_END_CODE  = 2,
	GET_RECEIPT_CODE = 3
}

local EDISIO_PROTOCOL = {
	[STATE.GET_BOOT_CODE] = {0x6C, 0x76, 0x63},
	[STATE.GET_END_CODE]  = {0x64, 0x0D, 0x0A},
	[STATE.GET_RECEIPT_CODE]  = {0x71, 0x68, 0x02, 0x01}
}


-- **************************************************
-- Globals
-- **************************************************

local g_parentDeviceId      -- The device # of the parent device

local g_edisioDevices = {}   -- The list of all our child devices
local g_indexEdisioDevicesByDeviceId = {}

local g_maxId = 0           -- A number that increments with every device learned.
local g_baseId = ""

-- **************************************************
-- Number functions
-- **************************************************

-- Formats a number as hex.
function number_toHex( n )
	if ( type( n ) == "number" ) then
		return string.format( "%02X", n )
	end
	return tostring( n )
end

-- **************************************************
-- Table functions
-- **************************************************

-- Merges (deeply) the contents of one table (t2) into another (t1)
function table_extend( t1, t2, excludedKeys )
	if ( ( t1 == nil ) or ( t2 == nil ) ) then
		return
	end
	local exclKeys
	if ( type( excludedKeys ) == "table" ) then
		exclKeys = {}
		for _, key in ipairs( excludedKeys ) do
			exclKeys[ key ] = true
		end
	end
	for key, value in pairs( t2 ) do
		if ( not exclKeys or not exclKeys[ key ] ) then
			if ( type( value ) == "table" ) then
				if ( type( t1[key] ) == "table" ) then
					t1[key] = table_extend( t1[key], value, excludedKeys )
				else
					t1[key] = table_extend( {}, value, excludedKeys )
				end
			elseif ( value ~= nil ) then
				if ( type( t1[key] ) == type( value ) ) then
					t1[key] = value
				else
					-- Try to keep the former type
					if ( type( t1[key] ) == "number" ) then
						luup.log( "table_extend : convert '" .. key .. "' to number " , 2 )
						t1[key] = tonumber( value )
					elseif ( type( t1[key] ) == "boolean" ) then
						luup.log( "table_extend : convert '" .. key .. "' to boolean" , 2 )
						t1[key] = ( value == true )
					elseif ( type( t1[key] ) == "string" ) then
						luup.log( "table_extend : convert '" .. key .. "' to string" , 2 )
						t1[key] = tostring( value )
					else
						t1[key] = value
					end
				end
			end
		elseif ( value ~= nil ) then
			t1[key] = value
		end
	end
	return t1
end


-- Checks if a table contains the given item.
-- Returns true and the key / index of the item if found, or false if not found.
function table_contains( t, item )
	for k, v in pairs( t ) do
		if ( v == item ) then
			return true, k
		end
	end
	return false
end

-- Checks if table contains all the given items (table).
function table_containsAll( t1, items )
	if ( ( type( t1 ) ~= "table" ) or ( type( t2 ) ~= "table" ) ) then
		return false
	end
	for _, v in pairs( items ) do
		if not table_contains( t1, v ) then
			return false
		end
	end
	return true
end

-- Appends the contents of the second table at the end of the first table
function table_append( t1, t2, noDuplicate )
	if ( ( t1 == nil ) or ( t2 == nil ) ) then
		return
	end
	local table_insert = table.insert
	if ( type( t2 ) == "table" ) then
		table.foreach(
			t2,
			function ( _, v )
				if ( noDuplicate and table_contains( t1, v ) ) then
					return
				end
				table_insert( t1, v )
			end
		)
	else
		if ( noDuplicate and table_contains( t1, t2 ) ) then
			return
		end
		table_insert( t1, t2 )
	end
	return t1
end

-- Extracts a subtable from the given table
function table_extract( t, start, length )
	if ( start < 0 ) then
		start = #t + start + 1
	end
	length = length or ( #t - start + 1 )

	local t1 = {}
	for i = start, start + length - 1 do
		t1[#t1 + 1] = t[i]
	end
	return t1
end

--[[
function table_concatChar( t )
	local res = ""
	for i = 1, #t do
		res = res .. string.char( t[i] )
	end
	return res
end
--]]

-- Concatenates a table of numbers into a string with Hex separated by the given separator.
function table_concatHex( t, sep, start, length )
	sep = sep or "-"
	start = start or 1
	if ( start < 0 ) then
		start = #t + start + 1
	end
	length = length or ( #t - start + 1 )
	local s = number_toHex( t[start] )
	if ( length > 1 ) then
		for i = start + 1, start + length - 1 do
			s = s .. sep .. number_toHex( t[i] )
		end
	end
	return s
end


-- **************************************************
-- String functions
-- **************************************************

-- Pads string to given length with given char from left.
function string_lpad( s, length, c )
	s = tostring( s )
	length = length or 2
	c = c or " "
	return c:rep( length - #s ) .. s
end

-- Pads string to given length with given char from right.
function string_rpad( s, length, c )
	s = tostring( s )
	length = length or 2
	c = char or " "
	return s .. c:rep( length - #s )
end

-- Splits a string based on the given separator. Returns a table.
function string_split( s, sep, convert, convertParam )
	if ( type( convert ) ~= "function" ) then
		convert = nil
	end
	if ( type( s ) ~= "string" ) then
		return {}
	end
	sep = sep or " "
	local t = {}
	for token in s:gmatch( "[^" .. sep .. "]+" ) do
		if ( convert ~= nil ) then
			token = convert( token, convertParam )
		end
		table.insert( t, token )
	end
	return t
end

-- Formats a string into hex.
function string_formatToHex( s, sep )
	sep = sep or "-"
	local result = ""
	if ( s ~= nil ) then
		for i = 1, string.len( s ) do
			if ( i > 1 ) then
				result = result .. sep
			end
			result = result .. string.format( "%02X", string.byte( s, i ) )
		end
	end
	return result
end


-- **************************************************
-- Generic utilities
-- **************************************************

function log( msg, methodName, lvl )
	local lvl = lvl or 50
	if ( methodName == nil ) then
		methodName = "UNKNOWN"
	else
		methodName = "(" .. _NAME .. "::" .. tostring( methodName ) .. ")"
	end
	luup.log( string_rpad( methodName, 45 ) .. " " .. tostring( msg ), lvl )
end

local function debug() end

local function warning( msg, methodName )
	log( msg, methodName, 2 )
end

local g_errors = {}
local function error( msg, methodName )
	table.insert( g_errors, { os.time(), tostring( msg ) } )
	if ( #g_errors > 100 ) then
		table.remove( g_errors, 1 )
	end
	log( msg, methodName, 1 )
	UI.showError( "Error (see tab)" )
end


-- **************************************************
-- Variable management
-- **************************************************

Variable = {
	-- Check if variable (service) is supported
	isSupported = function( deviceId, variable )
		if not luup.device_supports_service( variable[1], deviceId ) then
			warning( "Device #" .. tostring( deviceId ) .. " does not support service " .. variable[1], "Variable.isSupported" )
			return false
		end
		return true
	end,

	-- Get variable timestamp
	getTimestamp = function( deviceId, variable )
		if ( ( type( variable ) == "table" ) and ( type( variable[4] ) == "string" ) ) then
			local variableTimestamp = VARIABLE[ variable[4] ]
			if ( variableTimestamp ~= nil ) then
				return tonumber( ( luup.variable_get( variableTimestamp[1], variableTimestamp[2], deviceId ) ) )
			end
		end
		return nil
	end,

	-- Set variable timestamp
	setTimestamp = function( deviceId, variable, timestamp )
		if ( variable[4] ~= nil ) then
			local variableTimestamp = VARIABLE[ variable[4] ]
			if ( variableTimestamp ~= nil ) then
				luup.variable_set( variableTimestamp[1], variableTimestamp[2], ( timestamp or os.time() ), deviceId )
			end
		end
	end,

	-- Get variable value (can deal with unknown variable)
	get = function( deviceId, variable )
		deviceId = tonumber( deviceId )
		if ( deviceId == nil ) then
			error( "deviceId is nil", "Variable.get" )
			return
		elseif ( variable == nil ) then
			error( "variable is nil", "Variable.get" )
			return
		end
		local value, timestamp = luup.variable_get( variable[1], variable[2], deviceId )
		if ( value ~= "0" ) then
			local storedTimestamp = Variable.getTimestamp( deviceId, variable )
			if ( storedTimestamp ~= nil ) then
				timestamp = storedTimestamp
			end
		end
		return value, timestamp
	end,

	getUnknown = function( deviceId, serviceId, variableName )
		local variable = indexVariable[ tostring( serviceId ) .. ";" .. tostring( variableName ) ]
		if ( variable ~= nil ) then
			return Variable.get( deviceId, variable )
		else
			return luup.variable_get( serviceId, variableName, deviceId )
		end
	end,

	-- Set variable value
	set = function( deviceId, variable, value )
		deviceId = tonumber( deviceId )
		if ( deviceId == nil ) then
			error( "deviceId is nil", "Variable.set" )
			return
		elseif ( variable == nil ) then
			error( "variable is nil", "Variable.set" )
			return
		elseif ( value == nil ) then
			error( "value is nil", "Variable.set" )
			return
		end
		if ( type( value ) == "number" ) then
			value = tostring( value )
		end
		local doChange = true
		local currentValue = luup.variable_get( variable[1], variable[2], deviceId )
		local deviceType = luup.devices[deviceId].device_type
		--[[
		if (
			(variable == VARIABLE.TRIPPED)
			and (currentValue == value)
			and (
				(deviceType == DEVICE_TYPES.MOTION_SENSOR[1])
				or (deviceType == DEVICE_TYPES.DOOR_SENSOR[1])
				or (deviceType == DEVICE_TYPES.SMOKE_SENSOR[1])
			)
			and (luup.variable_get(VARIABLE.REPEAT_EVENT[1], VARIABLE.REPEAT_EVENT[2], deviceId) == "0")
		) then
			doChange = false
		elseif (
				(luup.devices[deviceId].device_type == tableDeviceTypes.LIGHT[1])
			and (variable == VARIABLE.LIGHT)
			and (currentValue == value)
			and (luup.variable_get(VARIABLE.VAR_REPEAT_EVENT[1], VARIABLE.VAR_REPEAT_EVENT[2], deviceId) == "1")
		) then
			luup.variable_set(variable[1], variable[2], "-1", deviceId)
		else--]]
		if ( ( currentValue == value ) and ( ( variable[3] == true ) or ( value == "0" ) ) ) then
			-- Variable is not updated when the value is unchanged
			doChange = false
		end

		if doChange then
			luup.variable_set( variable[1], variable[2], value, deviceId )
		end

		-- Updates linked variable for timestamp (just for active value)
		if ( value ~= "0" ) then
			Variable.setTimestamp( deviceId, variable, os.time() )
		end
	end,

	-- Get variable value and init if value is nil or empty
	getOrInit = function( deviceId, variable, defaultValue )
		local value, timestamp = Variable.get( deviceId, variable )
		if ( ( value == nil ) or (  value == "" ) ) then
			value = defaultValue
			Variable.set( deviceId, variable, value )
			timestamp = os.time()
			Variable.setTimestamp( deviceId, variable, timestamp )
		end
		return value, timestamp
	end,

	watch = function( deviceId, variable, callback )
		luup.variable_watch( callback, variable[1], variable[2], lul_device )
	end
}


-- **************************************************
-- UI messages
-- **************************************************

local g_taskHandle = -1     -- Handle for the system messages
local g_lastSysMessage = 0  -- Timestamp of the last status message

UI = {
	show = function( message )
		debug( "Display message: " .. tostring( message ), "UI.show" )
		Variable.set( g_parentDeviceId, VARIABLE.LAST_MESSAGE, message )
	end,

	showError = function( message )
		debug( "Display message: " .. tostring( message ), "UI.showError" )
		--message = '<div style="color:red">' .. tostring( message ) .. '</div>'
		message = '<font color="red">' .. tostring( message ) .. '</font>'
		Variable.set( g_parentDeviceId, VARIABLE.LAST_ERROR, message )
	end,

	clearError = function()
		Variable.set( g_parentDeviceId, VARIABLE.LAST_ERROR, "" )
	end,

	showSysMessage = function( message, mode, permanent )
		mode = mode or SYS_MESSAGE_TYPES.BUSY
		permanent = permanent or false
		log( "mode: " .. mode .. ", permanent: " .. tostring( permanent ) .. ", message: " .. message, "UI.showSysMessage" )

		luup.task( message, mode, "edisio gateway", g_taskHandle)
		g_lastSysMessage = tostring( os.time() )

		if not permanent then
			-- Clear the previous system message, since it's transient.
			luup.call_delay("EdisioGateway.UI.clearSysMessage", 30, g_lastSysMessage)
		elseif (mode == SYS_MESSAGE_TYPES.ERROR) then
			-- Critical error.
			luup.set_failure( true, g_parentDeviceId )
		end
	end,

	clearSysMessage = function (messageTime)
		-- 'messageTime' is nil if the function is called by the user.
		if ((messageTime == g_lastSysMessage) or (messageTime == nil)) then
			luup.task( "Clearing...", SYS_MESSAGE_TYPES.SUCCESS, "edisio gateway", g_taskHandle )
		end
	end
}


-- **************************************************
-- Device functions
-- **************************************************

local function _getEdisioDevice( productId, channelId )
	local edisioDevice = g_edisioDevices[ productId ]
	if ( edisioDevice ~= nil ) then
		if ( channelId ~= nil ) then
			channelId = tostring( channelId )
			if ( edisioDevice.channels[ channelId ] ~= nil) then
				return edisioDevice, edisioDevice.channels[ channelId ]
			end
		else
			return edisioDevice, nil
		end
	end
	return nil
end

local function _getDeviceId( productId, channelId )
	local productId = productId or "Unknown"
	local channelId = tostring( channelId or "1" )
	local edisioDevice, channel = _getEdisioDevice( productId, channelId )
	return channel.deviceId
end

local function _getEdisioDeviceFromDeviceId( deviceId )
	local index = g_indexEdisioDevicesByDeviceId[ tostring( deviceId ) ]
	if index then
		return index[1], index[2]
	else
		warning( "edisio device with deviceId #" .. tostring( deviceId ) .. "' is unknown", "getEdisioDevice" )
	end
	return nil
end

local function _getEdisioId( edisioDevice, channel )
	return edisioDevice.productId .. "," .. tostring( channel.id )
end

-- **************************************************
-- Discovered edisio devices
-- **************************************************

local g_discoveredDevices = {}

DiscoveredDevices = {
	add = function (productId, channelId, modelId)
		local hasBeenAdded = false
		local discoveredDevice = g_discoveredDevices[productId]
		if (discoveredDevice == nil) then
			local edisioInfos = _getEdisioInfos( modelId )
			discoveredDevice = {
				productId = productId,
				modelId = modelId,
				model = edisioInfos.model,
				modelDesc = edisioInfos.modelDesc,
				modelFunction = edisioInfos.modelFunction,
				channelIds = {},
				channelTypes = edisioInfos.deviceTypes,
				isReceiver = (edisioInfos.isReceiver == true)
			}
			g_discoveredDevices[productId] = discoveredDevice
			-- Add channelId(s)
			local nbChannels = edisioInfos.nbChannels or 1
			if ((nbChannels > 1) and (_getEdisioDevice(productId) == nil)) then
				for channelId = 1, nbChannels do
					table.insert(discoveredDevice.channelIds, channelId)
				end
			else
				discoveredDevice.channelIds = { channelId }
			end
			hasBeenAdded = true
			debug("Discovered edisio device '" .. productId .. "' and channel '" .. tostring(channelId) .. "'", "DiscoveredDevices.add")
		else
			if not table_contains(discoveredDevice.channelIds, channelId) then
				table.insert(discoveredDevice.channelIds, channelId)
				table.sort(discoveredDevice.channelIds)
				debug("Discovered edisio device '" .. productId .. "' and new channel '" .. tostring(channelId) .. "'", "DiscoveredDevices.add")
			end
			hasBeenAdded = true
		end
		discoveredDevice.lastUpdate = os.time()
		if hasBeenAdded then
			Variable.set(g_parentDeviceId, VARIABLE.LAST_DISCOVERED, os.time())
		end
		if hasBeenAdded then
			UI.show( "New edisio device discovered" )
		end
		return hasBeenAdded
	end,

	get = function (productId, channelId)
		channelId = tonumber(channelId)
		local discoveredEdisioDevice = g_discoveredDevices[productId]
		if ((discoveredEdisioDevice ~= nil) and (table_contains(discoveredEdisioDevice.channelIds, channelId))) then
			return discoveredEdisioDevice
		end
	end
}


-- **************************************************
-- Device helper
-- **************************************************

DeviceHelper = {
	-- Switch OFF/ON/TOGGLE
	setStatus = function( edisioDevice, channel, status, isLongPress, noCommand )
		if status then
			status = tostring( status )
		end
		local deviceId = channel.deviceId
		local formerStatus = Variable.get( deviceId, VARIABLE.SWITCH_POWER ) or "0"
		local msg = "Edisio device '" .. _getEdisioId( edisioDevice, channel ) .. "'"
		local isPulse = false
		if ( ( status == nil ) or ( status == "" ) ) then
			isPulse = ( Variable.get( deviceId, VARIABLE.PULSE_MODE ) == "1" )
			if isPulse then
				msg = msg .. " - Pulse"
				status = "1"
			else
				msg = msg .. " - Toggle"
				if ( formerStatus == "1" ) then
					status = "0"
				else
					status = "1"
				end
			end
		else
			msg = msg .. " - Switch"
		end

		-- Has status changed ?
		if ( status == formerStatus ) then
			debug( msg .. " - Status has not changed", "DeviceHelper.setStatus" )
			return
		end

		-- Update status variable
		-- TODO : mettre à jour le status seulement après confirmation de l'envoi ?
		local loadLevel
		if ( status == "1" ) then
			msg = msg .. " ON device #" .. tostring( deviceId )
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				loadLevel = Variable.get( deviceId, VARIABLE.DIMMER_LEVEL_OLD ) or "100"
				if ( loadLevel == "0" ) then
					loadLevel = "100"
				end
				msg = msg .. " at " .. loadLevel .. "%"
			end
		else
			msg = msg .. " OFF device #" .. tostring( deviceId )
			status = "0"
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				msg = msg .. " at 0%"
				loadLevel = 0
			end
		end
		if isLongPress then
			msg = msg .. " (long press)"
		end
		debug( msg, "DeviceHelper.setStatus" )
		Variable.set( deviceId, VARIABLE.SWITCH_POWER, status )
		if loadLevel then
			if ( loadLevel == 0 ) then
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL_OLD, Variable.get( deviceId, VARIABLE.DIMMER_LEVEL ) )
			end
			Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, loadLevel )
		end

		-- Send command if needed
		if ( ( edisioDevice.isReceiver ) and not ( noCommand == true ) ) then
			local cmd
			if ( status == "1" ) then
				cmd = EDISIO_COMMAND.ON
			else
				cmd = EDISIO_COMMAND.OFF
			end
			Network.send( {
				PID = channel.PID,
				--CID = tonumber(channel.id),
				-- TODO : à vérifier
				CID = 0x09,
				MID = 0x01,
				CMD = cmd
			} )
		end

		if ( isPulse and ( status == "1" ) ) then
			-- TODO : OFF après 200ms : voir multiswitch
			msg = "Edisio device '" .. _getEdisioId( edisioDevice, channel ) .. "' - Pulse OFF device #" .. tostring( deviceId )
			if luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) then
				debug( msg .. " at 0%", "DeviceHelper.setStatus" )
				Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL_OLD, Variable.get( deviceId, VARIABLE.DIMMER_LEVEL ) )
				Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, 0 )
			else
				debug( msg, "DeviceHelper.setStatus" )
				Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
			end
		end

		-- Association
		Association.propagate( channel.association, status, loadLevel, isLongPress )
		if ( isPulse and ( status == "1" ) ) then
			Association.propagate( channel.association, "0", nil, isLongPress )
		end

		return status
	end,

	-- Dim OFF/ON/TOGGLE
	setLoadLevel = function( edisioDevice, channel, loadLevel, direction, isLongPress, noCommand )
		loadLevel = tonumber( loadLevel )
		local deviceId = channel.deviceId
		local formerLoadLevel, lastLoadLevelChangeTime = Variable.get( deviceId, VARIABLE.DIMMER_LEVEL )
		formerLoadLevel = tonumber( formerLoadLevel ) or 0
		local msg = "Dim"

		if ( isLongPress and not luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], deviceId ) ) then
			-- Long press handled by a switch
			return DeviceHelper.setStatus( edisioDevice, channel, nil, isLongPress )

		elseif ( loadLevel == nil ) then
			-- Toggle dim
			loadLevel = formerLoadLevel
			if ( direction == nil ) then
				direction = Variable.getOrInit( deviceId, VARIABLE.DIMMER_DIRECTION, "up" )
				if ( os.difftime( os.time(), lastLoadLevelChangeTime ) > 2 ) then
					-- Toggle direction after 2 seconds of inactivity
					msg = "Toggle dim"
					if ( direction == "down" ) then
						direction = "up"
						Variable.set( deviceId, VARIABLE.DIMMER_DIRECTION, "up" )
					else
						direction = "down"
						Variable.set( deviceId, VARIABLE.DIMMER_DIRECTION, "down" )
					end
				end
			end
			if ( direction == "down" ) then
				loadLevel = loadLevel - 3
				msg = msg .. "-"
			else
				loadLevel = loadLevel + 3
				msg = msg .. "+"
			end
		end

		-- Update load level variable
		if ( loadLevel < 3 ) then
			loadLevel = 0
		elseif ( loadLevel > 100 ) then
			loadLevel = 100
		end

		-- Has load level changed ?
		if ( loadLevel == formerLoadLevel ) then
			debug( msg .. " - Load level has not changed", "DeviceHelper.setLoadLevel" )
			return
		end

		debug( msg .. " device #" .. tostring( deviceId ) .. " at " .. tostring( loadLevel ) .. "%", "DeviceHelper.setLoadLevel" )
		Variable.set( deviceId, VARIABLE.DIMMER_LEVEL, loadLevel )
		if (loadLevel > 0) then
			Variable.set( deviceId, VARIABLE.SWITCH_POWER, "1" )
		else
			Variable.set( deviceId, VARIABLE.SWITCH_POWER, "0" )
		end

		-- Send command if needed
		if ( ( edisioDevice.isReceiver ) and not ( noCommand == true ) ) then
			if ( loadLevel > 0 ) then
				Network.send( {
					PID = channel.PID,
					CID = 0x09,
					MID = 0x01,
					CMD = EDISIO_COMMAND.DIM,
					DATA = { loadLevel }
				} )
			else
				Network.send( {
					PID = channel.PID,
					CID = 0x09,
					MID = 0x01,
					CMD = EDISIO_COMMAND.OFF
				} )
			end
		end

		-- Association
		Association.propagate( channel.association, nil, loadLevel, isLongPress )

		return loadLevel
	end,

	-- Set armed
	setArmed = function( edisioDevice, channel, armed )
		local deviceId = channel.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.ARMED ) then
			return
		end
		armed = tostring( armed or "0" )
		if ( armed == "1" ) then
			debug( "Arm device #" .. tostring( deviceId ), "DeviceHelper.setArmed" )
		else
			debug( "Disarm device #" .. tostring( deviceId ), "DeviceHelper.setArmed" )
		end
		Variable.set( deviceId, VARIABLE.ARMED, armed )
		if ( armed == "0" ) then
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "0" )
		end
	end,

	-- Set tripped
	setTripped = function (edisioDevice, channel, tripped )
		local deviceId = channel.deviceId
		if not Variable.isSupported( deviceId, VARIABLE.TRIPPED ) then
			return
		end
		tripped = tostring( tripped or "0" )
		if ( tripped == "1" ) then
			debug( "Device #" .. tostring( deviceId ) .. " is tripped", "DeviceHelper.setTripped" )
		else
			debug( "Device #" .. tostring( deviceId ) .. " is untripped", "DeviceHelper.setTripped" )
		end
		Variable.set( deviceId, VARIABLE.TRIPPED, tripped )
		if ( ( tripped == "1" ) and ( Variable.get( deviceId, VARIABLE.ARMED) == "1" ) ) then
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "1" )
		else
			Variable.set( deviceId, VARIABLE.ARMED_TRIPPED, "0" )
		end
	end,

	-- Set temperature
	setTemperature = function( edisioDevice, channel, data )
		local deviceId = channel.deviceId
		local temperature = tostring( ( data[2] * 256 + data[1] ) / 100 ) -- degree celcius
		-- TODO : manage Fahrenheit
		debug( "Set device #" .. tostring(deviceId) .. " temperature to " .. tostring( temperature ) .. "°C", "DeviceHelper.setTemperature" )
		Variable.set( deviceId, VARIABLE.TEMPERATURE, temperature )
	end,

	-- Set battery level
	setBatteryLevel = function (edisioDevice, channel, BL)
		if not edisioDevice.isBatteryPowered then
			return
		end
		local deviceId = channel.deviceId
		--  3.3V is 100% (0x21), 2.6V is 0% (0x1A)
		local batteryLevel = math.ceil(((tonumber(BL) or 0) - 26) / 7 * 100)
		if (batteryLevel < 0) then
			batteryLevel = 0
		elseif (batteryLevel > 100) then
			batteryLevel = 100
		end
		debug("Set device #" .. tostring(deviceId) .. " battery level to " .. tostring(batteryLevel) .. "%", "DeviceHelper.setBatteryLevel")
		Variable.set(deviceId, VARIABLE.BATTERY_LEVEL, batteryLevel)
	end,

	-- Manage roller shutter
	moveShutter = function( edisioDevice, channel, direction, noCommand )
		-- TODO : sur quel channel il faut envoyer l'ordre pour 2 shutter ?
		
		debug("Shutter #" .. tostring(channel.deviceId) .. " direction: " .. tostring(direction), "DeviceHelper.moveShutter")
		
		-- Send command if needed
		if edisioDevice.isReceiver then
			local cmd
			if (direction == "up") then
				cmd = EDISIO_COMMAND.SHUTTER_OPEN
			elseif (direction == "down") then
				cmd = EDISIO_COMMAND.SHUTTER_CLOSE
			else
				cmd = EDISIO_COMMAND.SHUTTER_STOP
			end
			Network.send({
				PID = channel.PID,
				--CID = tonumber(channel.id),
				-- TODO : à vérifier
				CID = 0x00,
				MID = edisioDevice.modelId,
				CMD = cmd
			})
		end
		
	end,

	updateStatus = function( edisioDevice, channel, data )
		-- Should be only for receivers
		-- TODO : Attention - devrait se baser sur le type de device edisio et non le device Vera lié
		-- (peut poser pb si modifié à la main)
		if ( edisioDevice.deviceType == "BINARY_LIGHT" ) then
			DeviceHelper.setStatus( edisioDevice, channel, data[1], nil, true )
		elseif ( edisioDevice.deviceType == "DIMMABLE_LIGHT" ) then
			DeviceHelper.setLoadLevel( edisioDevice, channel, data[1], nil, nil, true )
		elseif ( edisioDevice.deviceType == "WINDOW_COVERING" ) then
			--DeviceHelper.moveShutter( edisioDevice, channel, data[1], true )
		--elseif ( edisioDevice.deviceType == "TEMPERATURE_SENSOR" ) then -- should not occured ?
		--	DeviceHelper.setTemperature( edisioDevice, channel, data )
		elseif ( edisioDevice.deviceType == "MOTION_SENSOR" ) then
			DeviceHelper.setTripped( edisioDevice, channel, data[1] )
		else
			--warning("Command DOOR_CLOSE not implemented for modelId " .. tostring(message.MID), "DeviceHelper.updateStatus")
		end
	end,

	updateStatuses = function( edisioDevice, channel, data )
		local edisioInfos = _getEdisioInfos( edisioDevice.modelId )
		local nbChannels = edisioInfos.nbChannels or 1
		if ( nbChannels > 1 ) then
			for i = 1, nbChannels do
				-- TODO : gérer la longueur des paramètres (shutter)
				local _, channel = _getEdisioDevice(edisioDevice.productId, i)
				if (channel ~= nil) then
					DeviceHelper.updateStatus(edisioDevice, channel, { data[i] })
				end
			end
		else
			DeviceHelper.updateStatus(edisioDevice, channel, data)
		end
	end
}


-- **************************************************
-- Message
-- **************************************************

local g_messageToProcessQueue = {}
local g_isProcessingMessage = false
local g_lastCommandsByEdisioId = {}

local COMMAND_HANDLERS = {

	[EDISIO_COMMAND.ON] = function( edisioDevice, channel, message )
		if ( message.MID == EDISIO_MODEL["EDS-100"] ) then
			-- pour porte ON = fermé ?
			DeviceHelper.setTripped( edisioDevice, channel, "0" )
		elseif ( channel.deviceType == DEVICE_TYPE.MOTION_SENSOR.deviceType ) then
			-- Motion sensor
			DeviceHelper.setTripped( edisioDevice, channel, "1" )
		else
			DeviceHelper.setStatus( edisioDevice, channel, "1" )
		end
		return true
	end,

	[EDISIO_COMMAND.OFF] = function( edisioDevice, channel, message )
		if ( message.MID == EDISIO_MODEL["EDS-100"] ) then
			-- pour porte OFF = ouvert ?
			DeviceHelper.setTripped( edisioDevice, channel, "1" )
		elseif ( channel.deviceType == DEVICE_TYPE.MOTION_SENSOR.deviceType ) then
			-- Motion sensor
			DeviceHelper.setTripped( edisioDevice, channel, "0" )
		else
			DeviceHelper.setStatus( edisioDevice, channel, "0" )
		end
		return true
	end,

	[EDISIO_COMMAND.TOGGLE] = function( edisioDevice, channel, message )
		DeviceHelper.setStatus( edisioDevice, channel )
		return true
	end,

	[EDISIO_COMMAND.DIM] = function( edisioDevice, channel, message )
		DeviceHelper.setLoadLevel( edisioDevice, channel, message.DATA[1] )
		return true
	end,

	[EDISIO_COMMAND.DIM_UP] = function( edisioDevice, channel, message )
		DeviceHelper.setLoadLevel( edisioDevice, channel, nil, "up" )
		return true
	end,

	[EDISIO_COMMAND.DIM_DOWN] = function( edisioDevice, channel, message )
		DeviceHelper.setLoadLevel( edisioDevice, channel, nil, "down" )
		return true
	end,

	[EDISIO_COMMAND.DIM_A] = function( edisioDevice, channel, message )
		-- long press on button ?
		DeviceHelper.setLoadLevel( edisioDevice, channel, nil, nil, true )
		return true
	end,

	--[[
	[EDISIO_COMMAND.SHUTTER_OPEN] = function( edisioDevice, channel, message )
		
	end

	[EDISIO_COMMAND.SHUTTER_CLOSE] = function( edisioDevice, channel, message )
		
	end
	--]]

	[EDISIO_COMMAND.DOOR_OPEN] = function( edisioDevice, channel, message )
		if ( message.MID == EDISIO_MODEL["EDS-100"] ) then
			DeviceHelper.setTripped( edisioDevice, channel, "1" )
		else
			warning( "Command DOOR_OPEN not implemented for modelId " .. tostring( message.MID ), "Message.process" )
			return false
		end
		return true
	end,

	--[[
	[EDISIO_COMMAND.DOOR_CLOSE] = function( edisioDevice, channel, message )
		if ( message.MID == EDISIO_MODEL.TEMPERATURE_SENSOR ) then
			DeviceHelper.setTemperature( edisioDevice, channel, message.DATA )
		elseif ( message.MID == EDISIO_MODEL.DOOR_SENSOR ) then
			DeviceHelper.setTripped( edisioDevice, channel, "0" )
		else
			warning( "Command DOOR_CLOSE not implemented for modelId " .. tostring( message.MID ), "Message.process" )
			return false
		end
		return true
	end,
	--]]

	[EDISIO_COMMAND.SET_TEMPERATURE] = function( edisioDevice, channel, message )
		DeviceHelper.setTemperature( edisioDevice, channel, message.DATA )
		return true
	end,

	[EDISIO_COMMAND.REPORT_STATUS] = function( edisioDevice, channel, message )
		--debug( "Update status for edisio device " .. edisioDevice.productId, "Message.process" )
		debug( "Update status for edisio device " .. edisioDevice.productId .. ": " .. number_toHex(message.DATA), "Message.process" )
		DeviceHelper.updateStatuses( edisioDevice, channel, message.DATA )
		return true
	end,

	[EDISIO_COMMAND.REPORT_CUSTOM] = function( edisioDevice, channel, message )
		-- TODO
		debug( "Report parameters for edisio device " .. edisioDevice.productId .. ": " .. number_toHex(message.DATA), "Message.process" )
		
		return true
	end
}

Message = {
	isRedondant = function( message )
		-- TODO : gérer RC (ré-emission)
		local edisioId = message.productId .. "," .. tostring( message.CID )
		local lastCommand = g_lastCommandsByEdisioId[ edisioId ]
		local msg = "Edisio device '" .. edisioId .. "' - Command " .. _getEdisioCommandName( message.CMD )
		--if ((message.CMD == lastCommand[2]) and (os.difftime(os.time(), lastCommand[1]) < 1)) then
		if ( ( lastCommand ~= nil ) and ( message.CMD == lastCommand[1] ) ) then
			if ( message.RC ~= lastCommand[4] ) then
				-- This message is a repeated message that has been previously already received
				debug( msg .. " - Discard repeated frame", "Message.isRedondant" )
				return true
			end
			local timeElapsed = math.ceil( ( os.clock() - lastCommand[3] ) * 1000 )
			--debug( msg .. " - Time elapsed " .. tostring( timeElapsed ) .. "ms", "Message.isRedondant" )
			if ( ( timeElapsed >= 0 ) and ( timeElapsed < 500 ) ) then
				-- Less than 500 ms between the two messages for the same edisio device and the same command
				lastCommand[2] = lastCommand[2] + 1
				if ( lastCommand[2] <= 4 ) then
					-- each message is emitted 4 times
					debug( msg .. " - Discard reemitted frame #" .. tostring( lastCommand[2] ) .. " (" .. tostring( timeElapsed ) .. "ms)", "Message.isRedondant" )
					return true
				end
			end
		end
		g_lastCommandsByEdisioId[ edisioId ] = { message.CMD, 1, os.clock(), message.RC }
		return false
	end,

	process = function( payload )
		local message = {
			productId = table_concatHex( payload, "-", 1 ,4 ),
			PID  = table_extract( payload, 1 ,4 ),
			CID  = payload[5],
			MID  = payload[6],
			BL   = payload[7],
			RMAX = payload[8],
			RC   = payload[9],
			CMD  = payload[10],
			DATA = table_extract( payload, 11 )
		}
		--debug("message=" .. json.encode(message), "Message.process")

		-- Discard redondant message
		if Message.isRedondant( message ) then
			return
		end

		local msg = "Edisio device '" .. message.productId .. "," .. tostring( message.CID ) .. "'"
		local edisioDevice, channel = _getEdisioDevice( message.productId, message.CID )
		if ( edisioDevice and channel ) then
			-- edisio device is known for this channel
			if ( COMMAND_HANDLERS[ message.CMD ] ~= nil ) then
				msg = msg .. " - Command " .. _getEdisioCommandName( message.CMD )
				if ( ( message.CMD == EDISIO_COMMAND.DIM_A ) and ( channel.lastCommand == EDISIO_COMMAND.DIM_A ) ) then
					local timeElapsed = math.ceil( ( os.clock() - channel.lastCommandReceiveTime ) * 1000 ) / 1000
					--print( "timeElapsed", timeElapsed, "channel.ignoreBurstTime", channel.ignoreBurstTime )
					if ( timeElapsed <= channel.ignoreBurstTime ) then
						debug( msg .. " - Ignore burst frame (last DIM_A, " .. tostring( timeElapsed ) .. "s ago, not at least " .. tostring( channel.ignoreBurstTime ) .. "s)", "Message.protectedProcess" )
						return
					else
						msg = msg .. " (last DIM_A, " .. tostring( timeElapsed ) .. "s ago)"
					end
				end
				debug( msg, "Message.process" )
				channel.lastCommand = message.CMD
				channel.lastCommandReceiveTime = os.clock()
				table.insert( g_messageToProcessQueue, { edisioDevice, channel, message } )
				luup.call_delay( "EdisioGateway.Message.deferredProcess", 0 )
			else
				--warning("Command 0x" .. number_toHex(message.CMD) .. " not yet implemented for message " .. table_concatHex(payload), "Message.process" )
				-- TODO : Do not expose edisio protocol ?
				warning( "Command 0x" .. number_toHex(message.CMD) .. " not yet implemented for edisio device " .. message.productId, "Message.process" )
			end
		else
			-- Add this device to the discovered edisio devices (but not known)
			if DiscoveredDevices.add( message.productId, message.CID, message.MID ) then
				debug( "This message is from an unknown edisio device '" .. message.productId .. "'", "Message.process" )
			else
				debug( "This message is from an edisio device already discovered '" .. message.productId .. "'", "Message.process" )
			end
		end
	end,

	deferredProcess = function()
		if g_isProcessingMessage then
			debug( "Processing is already in progress", "Message.deferredProcess" )
			return
		end
		g_isProcessingMessage = true
		local status, err = pcall( Message.protectedProcess )
		if err then
			error( "Error: " .. tostring( err ), "Message.deferredProcess" )
		end
		g_isProcessingMessage = false
	end,

	protectedProcess = function()
		while g_messageToProcessQueue[1] do
			local edisioDevice, channel, message = unpack( g_messageToProcessQueue[1] )
			if COMMAND_HANDLERS[ message.CMD ]( edisioDevice, channel, message ) then
				--channel.lastCommand = message.CMD
				--channel.lastCommandReceiveTime = os.clock()
			end
			if edisioDevice.isBatteryPowered then
				DeviceHelper.setBatteryLevel( edisioDevice, channel, message.BL )
			end
			table.remove( g_messageToProcessQueue, 1 )
		end
	end
}

-- **************************************************
-- Incoming data
-- **************************************************

local state        = STATE.GET_BOOT_CODE -- The current state
local protocolIdx  = 1
local rxBuf        = {} -- The received data buffer
local rxCount      = 0  -- The number of bytes in the data buffer

local function _clearBuffer()
	rxBuf = {}
	rxCount = 0
	protocolIdx = 1
end

function handleIncoming( lul_data )
	local rxByte = string.byte( lul_data )
--debug("state " .. state .. ", rxByte=" .. number_toHex(rxByte) .. ", rxCount=" .. rxCount .. ", protocolIdx=" .. protocolIdx, "handleIncoming")

	-- Add the received byte in the buffer
	rxCount = rxCount + 1
	if ( rxCount > 100 ) then
		-- There's a problem, the buffer is too large
		debug( "state " .. state ..", reset buffer", "handleIncoming" )
		state = STATE.GET_BOOT_CODE
		_clearBuffer()
		return
	end

	--rxBuf[rxCount] = rxByte
	table.insert( rxBuf, rxByte )
--debug("buffer: ".. table_concatHex(rxBuf), "handleIncoming")
	if ( EDISIO_PROTOCOL[state][protocolIdx] == rxByte ) then
		protocolIdx = protocolIdx + 1
		if ( protocolIdx > #EDISIO_PROTOCOL[state] ) then
			-- Protocol sequence has been found
			if (state == STATE.GET_BOOT_CODE) then
				-- Boot code 
--print("Boot code sequence has been found")
				state = STATE.GET_END_CODE
				_clearBuffer()
			elseif ( state == STATE.GET_END_CODE ) then
				-- Mark the end of the payload
--debug("Mark the end of the payload", "handleIncoming")
				--rxBuf[rxCount - #EDISIO_PROTOCOL[state] + 1] = nil
				for i = 1, #EDISIO_PROTOCOL[state] do
					table.remove(rxBuf)
				end
				debug( "*** payload received: " .. table_concatHex(rxBuf), "handleIncoming" )
				Message.process( rxBuf )
				state = STATE.GET_BOOT_CODE
				_clearBuffer()
			else
				-- problem ?
				debug( "problem", "handleIncoming" )
			end
		end
	elseif ( ( protocolIdx > 1 ) and ( EDISIO_PROTOCOL[state][1] == rxByte ) ) then
		protocolIdx = 2
	else
		protocolIdx = 1
	end
end


-- **************************************************
-- Network (outgoing data)
-- **************************************************

local g_messageToSendQueue = {}   -- The outbound message queue
local g_isSendingMessage = false

Network = {
	isEnabled = true,
	isPollingEnabled = true,

	-- Enable the edisio network
	enable = function()
		Network.isEnabled = true
	end,

	-- Disable the edisio network
	disable = function()
		Network.isEnabled = false
		g_messageToSendQueue = {}
	end,

	-- Send a message (add to send queue)
	send = function (message, delay)
		if not Network.isEnabled then
			debug("Can not send message: edisio network is disabled", "Network.send")
			return
		end

		local packet
		if (type(message) == "string") then
			packet = string.char(unpack(string_split(message, "-", tonumber, 16)))  
		else
			packet = string.char(unpack(EDISIO_PROTOCOL[STATE.GET_BOOT_CODE])) ..
				string.char(unpack(message.PID or {0x00, 0x00, 0x00, 0x00})) ..
				string.char(message.CID or 0x01) ..
				string.char(message.MID or 0x00) ..
				string.char(message.BL or 0x21) .. -- If BL = 0, the receiver bips
				string.char(message.RMAX or 0x05) ..
				string.char(0x00) ..
				string.char(message.CMD or 0x00)
			if (message.DATA ~= nil) then
				packet = packet .. string.char(unpack(message.DATA))
			end
			packet = packet .. string.char(unpack(EDISIO_PROTOCOL[STATE.GET_END_CODE]))
		end

		-- Delayed message
		if (delay) then
			luup.call_delay("EdisioGateway.Network.send", delay, string_formatToHex(packet, "-"))
			return
		end

		table.insert(g_messageToSendQueue, packet)
		if not g_isSendingMessage then
			Network.flush()
		end
	end,

	-- Send the packets in the queue to edisio dongle
	flush = function ()
		if not Network.isEnabled then
			debug("Can not send message: edisio network is disabled", "Network.flush")
			return
		end
		-- If we don't have any message to send, return.
		if (#g_messageToSendQueue == 0) then
			g_isSendingMessage = false
			return
		end

		g_isSendingMessage = true
		while g_messageToSendQueue[1] do
	debug( "Send message: ".. string_formatToHex(g_messageToSendQueue[1]), "Network.flush" )
			if not luup.io.write(g_messageToSendQueue[1]) then
				error( "Failed to send packet", "Network.flush" )
				return
			end
			table.remove(g_messageToSendQueue, 1)
		end

		--[[
		-- Send the next message in the queue.
		if (#g_messageToSendQueue > 0) then
			luup.call_delay("EdisioGateway.Network.flush", DELAYS.SEND_NEXT_MESSAGE)
		else
			g_isSendingMessage = false
		end
	--]]
		g_isSendingMessage = false
	end
}


-- **************************************************
-- Poll engine
-- **************************************************

PollEngine = {
	poll = function ()
		log( "Start poll", "PollEngine.start" )
	end
}


-- **************************************************
-- Tools
-- **************************************************

Tools = {
	-- Get PID (array representation of the Product ID)
	getPID = function (productId)
		if (productId == nil) then
			return nil
		end
		local PID = {}
		for i, strHex in ipairs(string_split(productId, "-")) do
			PID[i] = tonumber(strHex, 16)
		end
		return PID
	end,

	-- Generate virtual edisio Product ID
	-- TODO : juste un compteur ?
	generateProductId = function ()
		local virtualPID = { 0xFF }
		for i = 1, 3 do
			virtualPID[i] = math.random(0xFF + 1) - 1
		end
		return table_concatHex(virtualPID)
	end
}


-- **************************************************
-- Associations
-- **************************************************

Association = {
	-- Get associations from string
	get = function( strAssociation )
		local association = {}
		for _, encodedAssociation in pairs( string_split( strAssociation or "", "," ) ) do
			local linkedId, level, isScene, isEdisio = nil, 1, false, false
			while ( encodedAssociation ) do
				local firstCar = string.sub( encodedAssociation, 1 , 1 )
				if ( firstCar == "*" ) then
					isScene = true
					encodedAssociation = string.sub( encodedAssociation, 2 )
				elseif ( firstCar == "%" ) then
					isEdisio = true
					encodedAssociation = string.sub( encodedAssociation, 2 )
				elseif ( firstCar == "+" ) then
					level = level + 1
					if ( level > 2 ) then
						break
					end
					encodedAssociation = string.sub( encodedAssociation, 2 )
				else
					linkedId = tonumber( encodedAssociation )
					encodedAssociation = nil
				end
			end
			if linkedId then
				if isScene then
					if ( luup.scenes[ linkedId ] ) then
						if ( association.scenes == nil ) then
							association.scenes = { {}, {} }
						end
						table.insert( association.scenes[ level ], linkedId )
					else
						error("Associated scene #" .. tostring( linkedId ) .. " is unknown", "Associations.get")
					end
				elseif isEdisio then
					if ( luup.devices[ linkedId ] ) then
						if ( association.edisioDevices == nil ) then
							association.edisioDevices = { {}, {} }
						end
						table.insert( association.edisioDevices[ level ], linkedId )
					else
						error("Associated edisio device #" .. tostring( linkedId ) .. " is unknown", "Associations.get")
					end
				else
					if ( luup.devices[ linkedId ] ) then
						if ( association.devices == nil ) then
							association.devices = { {}, {} }
						end
						table.insert( association.devices[ level ], linkedId )
					else
						error("Associated device #" .. tostring( linkedId ) .. " is unknown", "Associations.get")
					end
				end
			end
		end
		return association
	end,

	getEncoded = function( association )
		local function _getEncodedAssociations( associations, prefix )
			local encodedAssociations = {}
			for level = 1, 2 do
				for _, linkedId in pairs( associations[ level ] ) do
					table.insert( encodedAssociations, string.rep( "+", level - 1 ) .. prefix .. tostring( linkedId ) )
				end
			end
			return encodedAssociations
		end
		local result = {}
		if association.devices then
			table_append( result, _getEncodedAssociations( association.devices, "" ) )
		end
		if association.scenes then
			table_append( result, _getEncodedAssociations( association.scenes, "*" ) )
		end
		if association.edisioDevices then
			table_append( result, _getEncodedAssociations( association.edisioDevices, "%" ) )
		end
		return table.concat( result, "," )
	end,

	propagate = function( association, status, loadLevel, isLongPress )
		if ( association == nil ) then
			return
		end

		local status = status or ""
		local loadLevel = tonumber( loadLevel ) or -1
		local level = 1
		if isLongPress then
			level = 2
		end

		-- Associated devices
		if association.devices then
			for _, linkedDeviceId in ipairs( association.devices[ level ] ) do
				--debug( "Linked device #" .. tostring( linkedDeviceId ), "Association.propagate")
				if ( ( loadLevel > 0 ) and luup.device_supports_service( VARIABLE.DIMMER_LEVEL[1], linkedDeviceId ) ) then
					debug( "Dim associated device #" .. tostring( linkedDeviceId ) .. " to " .. tostring( loadLevel ) .. "%", "Association.propagate" )
					luup.call_action( VARIABLE.DIMMER_LEVEL[1], "SetLoadLevelTarget", { newLoadlevelTarget = loadLevel }, linkedDeviceId )
				elseif luup.device_supports_service( VARIABLE.SWITCH_POWER[1], linkedDeviceId ) then
					if ( ( status == "1" ) or ( loadLevel > 0 ) ) then
						debug( "Switch ON associated device #" .. tostring( linkedDeviceId ), "Association.propagate" )
						luup.call_action( VARIABLE.SWITCH_POWER[1], "SetTarget", { newTargetValue = "1" }, linkedDeviceId )
					else
						debug( "Switch OFF associated device #" .. tostring( linkedDeviceId ), "Association.propagate" )
						luup.call_action( VARIABLE.SWITCH_POWER[1], "SetTarget", { newTargetValue = "0" }, linkedDeviceId )
					end
				else
					error( "Associated device #" .. tostring( linkedDeviceId ) .. " does not support services Dimming or SwitchPower", "Association.propagate" )
				end
			end
		end

		-- Associated scenes (just if status is ON)
		if ( association.scenes and ( ( status == "1" ) or ( loadLevel > 0 ) ) ) then
			for _, linkedSceneId in ipairs( association.scenes[ level ] ) do
				debug( "Call associated scene #" .. tostring(linkedSceneId), "Association.propagate" )
				luup.call_action( "urn:micasaverde-com:serviceId:HomeAutomationGateway1", "RunScene", { SceneNum = linkedSceneId }, 0 )
			end
		end
	end
}


-- **************************************************
-- Childs
-- **************************************************

-- Get a list with all our child devices.
local function _retrieveChildDevices()
	g_edisioDevices = {}
	g_indexEdisioDevicesByDeviceId = {}
	for deviceId, device in pairs( luup.devices ) do
		if ( device.device_num_parent == g_parentDeviceId ) then
			local productId, channelId = device.id:match( "^(%x%x%-%x%x%-%x%x%-%x%x),(%x)$" )
			if ( ( productId == nil ) or ( channelId == nil ) ) then
				debug( "Found child device #".. tostring( deviceId ) .."(".. device.description .."), but productId '" .. tostring( device.id ) .. "' does not match pattern '[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2},[0-9]'", "retrieveChildDevices" )
			else
				local modelId = tonumber( Variable.get( deviceId, VARIABLE.MODEL_ID ) or 0 ) or -1
				local edisioInfos = _getEdisioInfos( modelId )
				local edisioDevice = g_edisioDevices[productId]
				if ( edisioDevice == nil ) then
					edisioDevice = {
						productId = productId,
						PID = Tools.getPID( productId ),
						modelId = modelId,
						model = edisioInfos.model,
						modelDesc = edisioInfos.modelDesc,
						modelFunction = edisioInfos.modelFunction,
						channels = {},
						isButton = ( edisioInfos.isButton == true ),
						isReceiver = ( edisioInfos.isReceiver == true ),
						isBatteryPowered = ( edisioInfos.isBatteryPowered == true )
					}
					g_edisioDevices[productId] = edisioDevice
				else
					-- Check coherence with edisio device already registered
					if ( edisioDevice.modelId ~= modelId ) then
						warning(
							"Found device #".. tostring( deviceId ) .. "(".. device.description ..")," ..
							" productId=" .. productId .. ", channelId=" .. channelId ..
							" but its modelId '" .. tostring( modelId ) .. "' is not the modelId '" .. tostring( edisioDevice.modelId ) .. "' already registered",
							"retrieveChildDevices"
						)
					end
				end
				-- Channel
				if ( edisioDevice.channels[ channelId ] ~= nil ) then
					warning(
						"Found device #".. tostring( deviceId ) .."(".. device.description ..")," ..
						" productId=" .. productId .. ", channelId=" .. channelId ..
						" but this channel is already defined for device #" .. tostring( edisioDevice.channels[ channelId ].deviceId ) .. "(" .. luup.devices[ edisioDevice.channels[ channelId ].deviceId ].description .. ")",
						"retrieveChildDevices"
					)
				else
					local channel = {
						id = tonumber( channelId ),
						deviceId = deviceId,
						deviceType = device.device_type,
						lastCommand = 0,
						lastCommandReceiveTime = 0
					}
					edisioDevice.channels[channelId] = channel
					-- Check if channel is bound to a shutter (take two channels)
					if ( channel.deviceType == DEVICE_TYPE.WINDOW_COVERING.deviceType ) then
						edisioDevice.channels[ tostring( channel.id + 1 ) ] = channel
					end
					-- Virtual product ID
					local virtualProductId = Variable.get( deviceId, VARIABLE.PRODUCT_ID )
					if ( virtualProductId ~= nil ) then
						channel.PID = Tools.getPID( virtualProductId )
					end
					-- Association
					channel.association = Association.get( Variable.get( deviceId, VARIABLE.ASSOCIATION ) )
					-- Ignore burst time
					if edisioDevice.isButton then
						channel.ignoreBurstTime = tonumber( ( Variable.getOrInit( deviceId, VARIABLE.IGNORE_BURST_TIME, 1 ) ) ) or 0
					end
					-- Add to index
					g_indexEdisioDevicesByDeviceId[ tostring( deviceId ) ] = { edisioDevice, channel }
				end
				debug( "Found device #" .. tostring(deviceId) .. "(" .. device.description .. "), productId=" .. productId .. ", channelId=" .. channelId, "retrieveChildDevices" )
			end
		end
	end
	debug( json.encode(g_edisioDevices), "retrieveChildDevices" )
	-- Search unregistered channels
	for productId, edisioDevice in pairs( g_edisioDevices ) do
		if edisioDevice.isReceiver then
			local edisioInfos = _getEdisioInfos( edisioDevice.modelId )
			local channelId = 1
			while ( channelId <= ( edisioInfos.nbChannels or 1 ) ) do
				local channel = edisioDevice.channels[ tostring( channelId ) ]
				if ( channel == nil ) then
					DiscoveredDevices.add( productId, channelId, edisioDevice.modelId )
				elseif ( channel.deviceType == DEVICE_TYPE.WINDOW_COVERING.deviceType ) then
					-- Shutter take two channels
					--debug( "channel #" .. tostring( channelId ) .. " is shutter","retrieveChildDevices" )
					channelId = channelId + 1
				end
				channelId = channelId + 1
			end
		end
	end
end

local function _logEdisioDevices ()
	local nbEdisioDevices = 0
	local nbDevicesByModel = {}
	for productId, edisioDevice in pairs(g_edisioDevices) do
		nbEdisioDevices = nbEdisioDevices + 1
		if (nbDevicesByModel[edisioDevice.modelId] == nil) then
			nbDevicesByModel[edisioDevice.modelId] = 1
		else
			nbDevicesByModel[edisioDevice.modelId] = nbDevicesByModel[edisioDevice.modelId] + 1
		end
	end
	log("* Ediso devices: " .. tostring(nbEdisioDevices), "logEdisioDevices")
	for modelId, nbDevices in pairs(nbDevicesByModel) do
		local infos = _getEdisioInfos( modelId )
		log("*" .. string_lpad((infos.modelDesc or "UNKNOWN"), 20) .. ": " .. tostring(nbDevices), "logEdisioDevices")
	end
end


-- **************************************************
-- Serial connection
-- **************************************************

-- Check IO connection
local function _checkIoConnection()
	if not luup.io.is_connected( g_parentDeviceId ) then
		-- Try to connect by ip (openLuup)
		local ip = luup.attr_get( "ip", g_parentDeviceId )
		if ( ( ip ~= nil ) and ( ip ~= "" ) ) then
			local ipaddr, port = string.match( ip, "(.-):(.*)" )
			if ( port == nil ) then
				ipaddr = ip
				port = 80
			end
			log( "Open connection on ip " .. ipaddr .. " and port " .. port, "init" )
			luup.io.open( g_parentDeviceId, ipaddr, tonumber( port ) )
		end
	end
	if not luup.io.is_connected( g_parentDeviceId ) then
		error( "Serial port not connected. First choose the serial port and restart the lua engine.", "init" )
		UI.showSysMessage( "Choose the Serial Port", SYS_MESSAGE_TYPES.ERROR )
		return false
	else
		local ioDevice = tonumber(( Variable.get( g_parentDeviceId, VARIABLE.IO_DEVICE ) ))
		if ioDevice then
			-- Check serial settings
			-- TODO : si valeur vide forcer la valeur ?
			local baud = Variable.get( ioDevice, VARIABLE.BAUD ) or "9600"
			if ( baud ~= "9600" ) then
				error( "Incorrect setup of the serial port. Select 9600 bauds." )
				UI.showSysMessage( "Select 9600 bauds for the Serial Port", SYS_MESSAGE_TYPES.ERROR )
				return false
			end
			log( "Baud is 9600", "init" )

			-- TODO : Check Parity none / Data bits 8 / Stop bit 1
		end
	end
	log( "Serial port is connected", "init" )
	return true
end


-- **************************************************
-- HTTP request handler
-- **************************************************

local _handlerCommands = {
	["default"] = function( params, outputFormat )
		return "Unknown command '" .. tostring( params["command"] ) .. "'", "text/plain"
	end,

	["getDevicesInfos"] = function( params, outputFormat )
		log( "Get device list", "handleCommand.getDevicesInfos" )
		result = { devices = {}, discoveredDevices = {} }
		-- Known devices
		for _, edisioDevice in pairs( g_edisioDevices ) do
			local edisioDevice = table_extend( {}, edisioDevice ) -- Clone the device
			local channels = {}
			for channelId, channel in pairs( edisioDevice.channels ) do
				if ( channelId == tostring( channel.id ) ) then
					local device = luup.devices[ channel.deviceId ]
					channel.roomId = device.room_num
					channel.deviceName = device.description
					table.insert( channels, channel )
				end
			end
			edisioDevice.channels = channels
			table.insert( result.devices, edisioDevice )
		end
		-- Discovered devices
		for _, discoveredDevice in pairs( g_discoveredDevices ) do
			table.insert( result.discoveredDevices, discoveredDevice )
		end
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getDeviceParams"] = function( params, outputFormat )
		log( "Get device params", "handleCommand.getDeviceParams" )
		result = {}
		return tostring( json.encode( result ) ), "application/json"
	end,

	["getErrors"] = function( params, outputFormat )
		return tostring( json.encode( g_errors ) ), "application/json"
	end
}
setmetatable(_handlerCommands,{
	__index = function(t, command, outputFormat)
		log("No handler for command '" ..  tostring(command) .. "'", "handlerEdisioGateway")
		return _handlerCommands["default"]
	end
})

local function _handleCommand( lul_request, lul_parameters, lul_outputformat )
	--log("lul_request: " .. tostring(lul_request), "handleCommand")
	--log("lul_parameters: " .. tostring(json.encode(lul_parameters)), "handleCommand")
	--log("lul_outputformat: " .. tostring(lul_outputformat), "handleCommand")

	local command = lul_parameters["command"] or "default"
	log( "Get handler for command '" .. tostring(command) .."'", "handleCommand" )
	return _handlerCommands[command]( lul_parameters, lul_outputformat )
end


-- **************************************************
-- Action implementations
-- **************************************************

function teachIn( edisioId )
	local productId, channelId = unpack(string_split(edisioId, ","))
	local edisioDevice, channel = _getEdisioDevice(productId, channelId)
	if ( ( edisioDevice == nil ) or ( channel == nil ) ) then
		return
	end
	debug( "TEACH IN " .. tostring(edisioDevice.productId), "teachIn" )
	-- Study
	Network.send({
		PID = edisioDevice.PID,
		CID = tonumber(channelId),
		MID = EDISIO_MODEL.GATEWAY,
		CMD = EDISIO_COMMAND.STUDY
	})
	-- Pair virtual button
	Network.send({
		PID = channel.PID,
		CID = 0x09,
		MID = 0x01,
		--CMD = EDISIO_COMMAND.SET_SHORT
		CMD = EDISIO_COMMAND.TOGGLE
	}, 5 )
	-- Validate
	Network.send({
		PID = edisioDevice.PID,
		CID = tonumber(channelId),
		MID = EDISIO_MODEL.GATEWAY,
		CMD = EDISIO_COMMAND.STUDY
	}, 10 )
end

function clear( edisioId )
	local productId, channelId = unpack( string_split( edisioId, "," ) )
	local edisioDevice, channel = _getEdisioDevice( productId, channelId )
	if ( edisioDevice == nil ) then
		return
	end
	local edisioInfos = _getEdisioInfos( edisioDevice.modelId )
	debug( "CLEAR " .. tostring( edisioDevice.productId ), "teachIn" )
	-- Study
	Network.send( {
		PID = edisioDevice.PID,
		CID = edisioInfos.nbChannels or tonumber( channelId ),
		MID = EDISIO_MODEL.GATEWAY,
		CMD = EDISIO_COMMAND.DEL_ALL
	} )
end

function setTarget( childDeviceId, newTargetValue )
	if ( childDeviceId == g_parentDeviceId ) then
		-- Switch ON/OFF Gateway
		if ( tostring( newTargetValue ) == "1" ) then
			Network.enable()
			Variable.set( g_parentDeviceId, VARIABLE.SWITCH_POWER, "1" )
		else
			Network.disable()
			Variable.set( g_parentDeviceId, VARIABLE.SWITCH_POWER, "0" )
		end
	else
		local edisioDevice, channel = _getEdisioDeviceFromDeviceId( childDeviceId )
		if (edisioDevice == nil) then
			error( "Device #" .. tostring( childDeviceId ) .. " is not an edisio device", "setTarget" )
			return
		end
		DeviceHelper.setStatus( edisioDevice, channel, newTargetValue )
	end
	return JOB_STATUS.DONE, nil
end

function setLoadLevelTarget (childDeviceId, newLoadlevelTarget)
	local edisioDevice, channel = _getEdisioDeviceFromDeviceId( childDeviceId )
	if ( edisioDevice == nil ) then
		error( "Device #" .. tostring( childDeviceId ) .. " is not an edisio device", "setLoadLevelTarget" )
		return
	end
	DeviceHelper.setLoadLevel( edisioDevice, channel, newLoadlevelTarget )
	-- tODO : poll 10 secondes après pour vérifier
	return JOB_STATUS.DONE, nil
end

function setArmed( childDeviceId, newArmedValue )
	local edisioDevice, channel = _getEdisioDeviceFromDeviceId( childDeviceId )
	if ( edisioDevice == nil ) then
		error( "Device #" .. tostring( childDeviceId ) .. " is not an edisio device", "setArmed" )
		return
	end
	DeviceHelper.setArmed( edisioDevice, channel, newArmedValue or "0" )
	return JOB_STATUS.DONE, nil
end

function moveShutter( childDeviceId, direction )
	local edisioDevice, channel = _getEdisioDeviceFromDeviceId( childDeviceId )
	if ( edisioDevice == nil ) then
		error( "Device #" .. tostring( childDeviceId ) .. " is not an edisio device", "up" )
		return
	end
	DeviceHelper.moveShutter( edisioDevice, channel, direction )
	return JOB_STATUS.DONE, nil
end

function refresh()
	debug( "Refresh edisio devices", "refresh" )
	_retrieveChildDevices()
	_logEdisioDevices()
	return JOB_STATUS.DONE, nil
end

function createDevices( edisioIds )
	debug( "Create edisio product/channel/type '" .. tostring( edisioIds ) .. "'", "createDevices" )

	local edisioDevicesToAdd = {}
	for _, edisioId in ipairs( string_split( edisioIds, "|" ) ) do
		local productId, channelId, deviceTypeName = unpack( string_split( edisioId, "," ) )
		local discoveredDevice = DiscoveredDevices.get( productId, channelId )
		if ( discoveredDevice ~= nil ) then
			local edisioInfos = _getEdisioInfos( discoveredDevice.modelId )
			if ( deviceTypeName == nil ) then
				deviceTypeName = edisioInfos.deviceTypes[1]
			end
			if table_contains( edisioInfos.deviceTypes, deviceTypeName ) then
				table.insert( edisioDevicesToAdd, { productId, channelId, discoveredDevice.modelId, deviceTypeName } )
			end
		end
	end
	if ( #edisioDevicesToAdd == 0 ) then
		debug( "Unknown edisio devices '" .. tostring( edisioIds ) .. "'", "createDevices" )
		return JOB_STATUS.ERROR, "Unknown edisio devices"
	end

	-- http://wiki.micasaverde.com/index.php/Luup_Lua_extensions#Module:_luup.chdev
	local ptr = luup.chdev.start( g_parentDeviceId )

	-- Keep former known edisio devices
	for productId, edisioDevice in pairs( g_edisioDevices ) do
		for channelId, channel in pairs( edisioDevice.channels ) do
			local edisioId = productId .. "," .. channelId
			local device = luup.devices[ channel.deviceId ]
			debug( "edisio productId '" .. productId .. "', channel " .. channelId .. " - Keep device #" .. tostring( channel.deviceId ) .. "(" .. device.description .. ")", "createDevices" )
			luup.chdev.append( g_parentDeviceId, ptr, edisioId, "", "", "", "", "", false )
		end
	end

	-- Add new devices
	for _, productChannel in ipairs( edisioDevicesToAdd ) do
		local productId, channelId, modelId, deviceTypeName = unpack( productChannel )
		local edisioId = productId .. "," .. channelId
		local edisioInfos = _getEdisioInfos( modelId )
		local deviceTypeInfos = DEVICE_TYPE[ deviceTypeName ]
		local parameters = ""
		if ( deviceTypeInfos.parameters ~= nil ) then
			parameters = deviceTypeInfos.parameters .. "\n" 
		end
		parameters = parameters .. VARIABLE.MODEL_ID[1] .. "," .. VARIABLE.MODEL_ID[2] .. "=" .. tostring( modelId ) .. "\n"
		parameters = parameters .. VARIABLE.ASSOCIATION[1] .. "," .. VARIABLE.ASSOCIATION[2] .. "=\n"
		if ( edisioInfos.isReceiver ) then
			-- Create virtual Product ID
			local virtualProductId = Tools.generateProductId()
			parameters = parameters .. VARIABLE.PRODUCT_ID[1] .. "," .. VARIABLE.PRODUCT_ID[2] .. "=" .. tostring( virtualProductId ) .. "\n"
		end
		if ( edisioInfos.isButton ) then
			parameters = parameters .. VARIABLE.PULSE_MODE[1] .. "," .. VARIABLE.PULSE_MODE[2] .. "=0\n"
		end
		debug( "Add edisio productId '" .. productId .. "', channel '" .. channelId .. "', deviceFile '" .. deviceTypeInfos.deviceFile .. "'", "createDevices" )
		luup.chdev.append(
			g_parentDeviceId, ptr, edisioId,
			productId .. " / " .. channelId, "", deviceTypeInfos.deviceFile, "",
			parameters,
			false
		)
	end

	debug( "Start sync", "createDevices" )
	Variable.set( g_parentDeviceId, VARIABLE.LAST_UPDATE, os.time() )
	luup.chdev.sync( g_parentDeviceId, ptr )
	debug( "End sync", "createDevices" )

	return JOB_STATUS.DONE, nil
end

function associate( edisioId, strAssociation )
	local productId, channelId = unpack( string_split( edisioId, "," ) )
	local edisioDevice, channel = _getEdisioDevice( productId, channelId )
	if ( ( edisioDevice == nil ) or ( channel == nil ) ) then
		return
	end
	debug("ASSOCIATE edisio device '" .. tostring( edisioDevice.productId ) .. "' and channel #" .. channelId .. " with " .. tostring( strAssociation ), "associate" )
	channel.association = Association.get( strAssociation )
	Variable.set( channel.deviceId, VARIABLE.ASSOCIATION, Association.getEncoded( channel.association ) )
end

function poll( childDeviceId )
	local edisioDevice, channel = _getEdisioDeviceFromDeviceId(childDeviceId)
	if (edisioDevice == nil) then
		return JOB_STATUS.ERROR, "Unknown edisio device"
	end
	debug("Poll edisio device with productId '" .. edisioDevice.productId .. "' for device #" .. tostring(childDeviceId), "poll")
	if not edisioDevice.isReceiver then
		return JOB_STATUS.ERROR, "device #" .. tostring(childDeviceId) .. " is not linked to an edisio receiver"
	end
	
	Network.send({
		PID = edisioDevice.PID,
		MID = EDISIO_MODEL.GATEWAY,
		CMD = EDISIO_COMMAND.QUERY_STATUS
	})
	return JOB_STATUS.DONE, nil
end

function reconfigure( childDeviceId )
	local edisioDevice, channel = _getEdisioDeviceFromDeviceId(childDeviceId)
	if (edisioDevice == nil) then
		return JOB_STATUS.ERROR, "Unknown edisio device"
	end
	--[[
	debug("Poll edisio device with productId '" .. edisioDevice.productId .. "' for device #" .. tostring(childDeviceId), "poll")
	if not edisioDevice.isReceiver then
		return JOB_STATUS.ERROR, "device #" .. tostring(childDeviceId) .. " is not linked to an edisio receiver"
	end
	
	Network.send({
		PID = edisioDevice.PID,
		MID = EDISIO_MODEL.GATEWAY,
		CMD = EDISIO_COMMAND.READ_CUSTOM
	})
	--]]
	return JOB_STATUS.DONE, nil
end

-- DEBUG METHOD
function sendMessage( message, job )
debug("Send message: " .. message, "sendMessage")
	--[[local packet = ""
	local hexCodes = string_split(message, "-")
	for _, hex in ipairs(hexCodes) do
		packet = packet .. string.char(tonumber(hex, 16) or 0)
	end
	--]]
	Network.send(message)
	return JOB_STATUS.DONE, nil
end


-- **************************************************
-- Startup
-- **************************************************

-- Init plugin instance
local function _initPluginInstance()
	log( "Init", "initPluginInstance" )

	-- Update the Debug Mode
	local debugMode = ( Variable.getOrInit( g_parentDeviceId, VARIABLE.DEBUG_MODE, "0" ) == "1" ) and true or false
	if debugMode then
		log( "DebugMode is enabled", "init" )
		debug = log
	else
		log( "DebugMode is disabled", "init" )
		debug = function() end
	end

	Network.isEnabled = ( Variable.getOrInit(g_parentDeviceId, VARIABLE.SWITCH_POWER, "1" ) == "1" )
	Network.isPollingEnabled = ( Variable.getOrInit(g_parentDeviceId, VARIABLE.POLLING_ENABLED, "1" ) == "1" )

	Variable.set( g_parentDeviceId, VARIABLE.PLUGIN_VERSION, _VERSION )
	Variable.getOrInit( g_parentDeviceId, VARIABLE.LAST_UPDATE, "" )
	Variable.set( g_parentDeviceId, VARIABLE.LAST_MESSAGE, "" )
	Variable.set( g_parentDeviceId, VARIABLE.LAST_ERROR, "" )
	Variable.getOrInit( g_parentDeviceId, VARIABLE.LAST_DISCOVERED, "" )
end

-- Register with ALTUI once it is ready
local function _registerWithALTUI ()
	for deviceId, device in pairs(luup.devices) do
		if (device.device_type == "urn:schemas-upnp-org:device:altui:1") then
			if luup.is_ready(deviceId) then
				log("Register with ALTUI main device #" .. tostring(deviceId), "registerWithALTUI")
				luup.call_action(
					"urn:upnp-org:serviceId:altui1",
					"RegisterPlugin",
					{
						newDeviceType = "urn:schemas-upnp-org:device:EdisioGateway:1",
						newScriptFile = "J_EdisioGateway1.js",
						newDeviceDrawFunc = "EdisioGateway.ALTUI_drawDevice"
					},
					deviceId
				)
			else
				log("ALTUI main device #" .. tostring(deviceId) .. " is not yet ready, retry to register in 10 seconds...", "registerWithALTUI")
				luup.call_delay("EdisioGateway.registerWithALTUI", 10)
			end
			break
		end
	end
end

function init( lul_device )
	log("Init edisio Gateway plugin v" .. _VERSION, "init")

	-- Get the master device
	g_parentDeviceId = lul_device

	-- Get a handle for system messages
	g_taskHandle = luup.task("Starting up...", 1, "edisio gateway", -1)

	-- Update static JSON file
	if _updateStaticJSONFile(g_parentDeviceId, _NAME .. "1") then
		UI.showSysMessage( "'device_json' has been updated : reload LUUP engine", SYS_MESSAGE_TYPES.ERROR )
		if ((luup.version_branch == 1) and (luup.version_major > 5)) then
			luup.reload()
		end
		return true, "Reload LUUP engine"
	end
	
	if ( type( json ) == "string" ) then
		UI.showError( "No JSON decoder" )
	elseif _checkIoConnection() then
		-- Init
		_initPluginInstance()

		-- Get the list of the child devices
		math.randomseed( os.time() )
		_retrieveChildDevices()
		_logEdisioDevices()
	end

	-- Watch setting changes
	Variable.watch( lul_device, VARIABLE.DEBUG_MODE, "EdisioGateway.initPluginInstance" )
	Variable.watch( lul_device, VARIABLE.POLLING_ENABLED, "EdisioGateway.initPluginInstance" )

	-- Handlers
	luup.register_handler( "EdisioGateway.handleCommand", "EdisioGateway" )

	-- Register with ALTUI
	luup.call_delay( "EdisioGateway.registerWithALTUI", 10 )

	if ( luup.version_major >= 7 ) then
		luup.set_failure( 0, lul_device )
	end

	log( "Startup successful", "init" )
	return true, "startup successful", "edisio gateway"
end


-- Promote the functions used by Vera's luup.xxx functions to the global name space
_G["EdisioGateway.handleCommand"] = _handleCommand
_G["EdisioGateway.UI.clearSysMessage"] = UI.clearSysMessage
_G["EdisioGateway.Message.deferredProcess"] = Message.deferredProcess
_G["EdisioGateway.Network.send"] = Network.send

_G["EdisioGateway.initPluginInstance"] = _initPluginInstance
_G["EdisioGateway.registerWithALTUI"] = _registerWithALTUI
