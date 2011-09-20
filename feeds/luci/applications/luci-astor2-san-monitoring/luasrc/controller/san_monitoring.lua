--[[
  aStor2 -- storage area network configurable via Web-interface
  Copyright (C) 2009-2011 ETegro Technologies, PLC
                          Vladimir Petukhov <vladimir.petukhov@etegro.com>
                          Sergey Matveev <stargrave@stargrave.org>
  
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

module( "luci.controller.san_monitoring", package.seeall )

common = require( "astor2.common" )
require( "luci.controller.san_monitoring_configuration" )
matrix = require( "luci.controller.matrix" )
einarc = require( "astor2.einarc" )

require( "luci.i18n" ).loadc( "astor2_san")

function index()
	local i18n = luci.i18n.translate
	local e = entry( { "admin", "san", "monitoring" },
	                 call( "monitoring_overall" ),
	                 i18n("Monitoring"),
	                 11 )
	e.i18n = "astor2_san"
	e = entry( { "admin", "san", "monitoring", "render" },
	             call( "render" ), nil, 11 )
	e.leaf = true
end

local function index_with_error( message_error )
	local http = luci.http
	if message_error then message_error = tostring( message_error ) end
	http.redirect( luci.dispatcher.build_url( "admin", "san", "monitoring" ) .. "/" ..
	               http.build_querystring( { message_error = message_error } ) )
end

function monitoring_overall()
	local message_error = luci.http.formvalue( "message_error" )
	luci.template.render( "san_monitoring", { data = {} } )
end

local function render_svg( svg_filename, data )
	luci.http.prepare_content( "image/svg+xml" )
	luci.template.render( "san_monitoring/" .. svg_filename .. ".svg", { data = data } )
end

--[[
+------+-------+-------------+---------+------------+--------+
| 1    | 2     | 3           | 4       | 5          | 6      |
|------+-------+-------------+---------+------------+--------|
| time | value | low non-crt | low crt | up non-crt | up-crt |
+------+-------+-------------+---------+------------+--------+
--]]
local function determine_color( result )
	local numberized = {}
	for _, v in ipairs( result ) do
		numberized[ #numberized + 1 ] = tonumber( v )
	end
	result = numberized

	if result[2] > result[3] and
	   result[2] < result[5] then
		return "green"
	end
	if result[2] > result[4] and
	   result[2] < result[3] then
		return "orange"
	end
	if result[2] > result[5] and
	   result[2] < result[6] then
		return "orange"
	end
	return "red"
end

local function bwc_data_get( what )
	local data = {}
	for ipmi_id, template_id in pairs( luci.controller.san_monitoring_configuration.configuration[ what ] ) do
		local bwc = io.popen("luci-bwc-ipmi \"" .. ipmi_id .. "\" last 2>/dev/null")
		local result = common.split_by( bwc:read("*l"), " " )
		bwc:close()
		if #result == 0 then
			data[ template_id ] = {}
		else
			data[ template_id ] = {
				value = result[2],
				color = determine_color( result )
			}
		end
	end
	return data
end
--[[
local function network_data_get( data )
	for eth_id, template_id in pairs( luci.controller.san_monitoring_configuration.network ) do
		data[ template_id ] = {}
		for _, line in ipairs( common.system( "ethtool " .. eth_id ).stdout ) do
			local link_detected = string.match( line, "^%s*Link detected: (%w+)$" )
			if link_detected then
				data[ template_id ][ "link" ] = ({
					["yes"] = true,
					["no"] = false
				})[ link_detected ]
			end

			local speed = string.match( line, "^%s*Speed: (%d+).*$" )
			if speed then
				data[ template_id ][ "speed" ] = tonumber( speed )
			end
		end
	end
	return data
end
]]

local function pci_data_get( data )
	for _, line in ipairs( common.system( "cat /proc/bus/pci/devices" ).stdout ) do
		--0700    808610d3    10          df6e0000                   0                dc01            df6dc000                   0                   0                   0               20000                   0                  20                4000                   0                   0                   0    e1000e
		--0800    808610d3    10          df6e0000                   0                dc01            df6dc000                   0                   0                   0               20000                   0                  20                4000                   0                   0                   0
		local pattern_chapter, step_string = "", "%s*%w*"
		for n = 1, 15 do
			pattern_chapter = pattern_chapter .. step_string
		end
		local pattern = "^(%d%d)(%d%d)%s*(%w%w%w%w)(%w%w%w%w)" .. pattern_chapter .. "%s*(%w*)$"
		local slot_id, port_id, vendor_id, device_id, kernel_driver = string.match( line, pattern )

		-- Checking for slot and port
		if slot_id and port_id then
			slot_id, port_id = "SLOT" .. tonumber( slot_id ), "PORT" .. tonumber( port_id )

			data[ slot_id ] = {}
			data[ slot_id ][ port_id ] = {}
			-- Filling slots and ports
			if vendor_id and device_id then
				data[ slot_id ][ port_id ] = {
					[ "vendor_id" ] = vendor_id,
					[ "device_id" ] = device_id
				}
				if kernel_driver and kernel_driver ~= "" then
					data[ slot_id ][ port_id ][ "kernel_driver" ] = kernel_driver
				end
			end
		end
	end
	return data
end

local function network_data_get( data )
	for _, line in ipairs( common.system( "ifconfig -a | grep '^eth'" ).stdout ) do
		--$ ifconfig -a | grep ^eth
		--eth0      Link encap:Ethernet  HWaddr XX:XX:XX:XX:XX:XX
		local eth_id = string.match( line, "^(eth%d+)%s.*$" )
		if eth_id then
			--$ ethtool -i eth0
			--driver: e1000e
			--version: 1.0.2-k2
			--firmware-version: 1.8-0
			--bus-info: 0000:07:00.0
			for _, line in ipairs( common.system( "ethtool -i " .. eth_id ).stdout ) do
				--local kernel_driver = string.match( line, "^driver:%s(.*)$" )
				local slot_id, port_id = string.match( line, "^bus.info:%s%d+:(%d+):%d+.(%d+)$" )
				if slot_id and port_id then
					slot_id, port_id = "SLOT" .. tonumber( slot_id ), "PORT" .. tonumber( port_id )
					if data[ slot_id ][ port_id ] then
						data[ slot_id ][ port_id ][ "port_name" ] = eth_id

						for _, line in ipairs( common.system( "ethtool " .. eth_id ).stdout ) do
							local link_detected = string.match( line, "^%s*Link%sdetected:%s(%w+)$" )
							if link_detected then
								data[ slot_id ][ port_id ][ "link" ] = ( {
									[ "yes" ] = true,
									[ "no" ] = false
								} )[ link_detected ]
							end

							local speed = string.match( line, "^%s*Speed:%s(%d+).*$" )
							if speed then
								data[ slot_id ][ port_id ][ "speed" ] = tonumber( speed )
							end
						end
					end
				end
			end
		end
	end
	return data
end

function render()
	local what = luci.http.formvalue( "what" )
	local pci = luci.http.formvalue( "pci" )
	local network = luci.http.formvalue( "network" )
	local enclosures = luci.http.formvalue( "enclosures" )
	local bwc = luci.http.formvalue( "bwc" )

	local data = {}
	if bwc then data = bwc_data_get( what ) end
	if pci then data = pci_data_get( data ) end
	if network then data = network_data_get( data ) end
	if enclosures then
		matrix_data = matrix.caller_minimalistic( {
			matrix.filter_borders_highlight,
			matrix.filter_alternation_border_colors,
			matrix.filter_physical_enclosures
		} )
		-- Postprocess enclosures
		enclosures = {}
		for _, line in ipairs( matrix_data.lines ) do
			if line.physical and line.physical.enclosure_id then
				local physical = line.physical
				local enclosure_id = luci.controller.san_monitoring_configuration.enclosures[ physical.enclosure_id ]
				enclosures[ enclosure_id ] = { physical_id = physical.id }

				local color = "gray"
				if physical.highlight.color then
					color = physical.highlight.color
					if physical.state == "hotspare" then
						color = "dark" .. color
					end
				end
				enclosures[ enclosure_id ].color = color
			end
		end
		for _, line in ipairs( matrix_data.lines ) do
			if line.logical then
				for physical_id,_ in pairs( line.logical.physicals ) do
					for enclosure_id, enclosure in pairs( enclosures ) do
						if enclosure.physical_id == physical_id then
							enclosure.logical_id = line.logical.id
						end
					end
				end
			end
		end
		for template_id, enclosure in pairs( enclosures ) do
			data[ template_id ] = enclosure
		end
	end
	return render_svg( what, data )
end
