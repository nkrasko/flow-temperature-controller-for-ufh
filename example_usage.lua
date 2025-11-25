-- Copyright 2025 Nikolay V. Krasko
-- Licensed under GNU GPLv3
-- Example usage of Flow Temperature Controller

-- Load the controller module
local FlowTemperatureController = require("flow_temperature_controller")

-- Create a new controller with configuration
local controller = FlowTemperatureController:new({
    curve_type = 'linear', -- "linear", "logarithmic", or "exponential"
    room_temp_target = 21,     -- Target room temperature (°C)
    min_flow_temp = 25,        -- Minimum flow temperature (°C)
    max_flow_temp = 45,        -- Maximum flow temperature for underfloor heating (°C)
    base_outdoor_temp = 18,    -- Outdoor temp at which heating turns off (°C)
    design_outdoor_temp = -15, -- Design outdoor temperature (°C)
    curve_slope = 0.6,           -- Heating curve slope (higher = more aggressive)
    curve_offset = 0           -- Additional offset for fine-tuning (°C)
})

-- Add heating zones
-- Zone ID, Area (sqm), Base heat demand (W/sqm), Temperature target (°C)
controller:add_zone("living_room", 35, 100, 21)
controller:add_zone("bedroom_1", 18, 90, 19)
controller:add_zone("bedroom_2", 15, 90, 19)
controller:add_zone("bathroom", 8, 100, 23)
controller:add_zone("kitchen", 22, 95, 20)

-- Simulate system operation
print("=== Flow Temperature Controller Example ===\n")

-- Function to print results nicely
local function print_results(outdoor_temp)
    local result = controller:calculate_flow_temperature(outdoor_temp)

    print(string.format("Outdoor Temperature: %.1f°C", outdoor_temp))
    print(string.format("Base Flow Temperature: %.1f°C", result.base_flow_temperature))
    print(string.format("Adjusted Flow Temperature: %.1f°C", result.flow_temperature))
    print(string.format("Total Heat Demand: %.0f W", result.total_demand_w))
    print(string.format("Total Area: %.1f sqm", result.total_area_sqm))
    print(string.format("Active Zones: %d", result.active_zones))
    print(string.format("Demand Adjustment: %.2f", result.demand_adjustment))
    print("")
end

-- Test 1: Normal operation with all zones active
print("--- Test 1: All zones active, outdoor temp 5°C ---")
print_results(5)

-- Test 2: Colder weather
print("--- Test 2: Cold weather, outdoor temp -10°C ---")
print_results(-10)

-- Test 3: Mild weather
print("--- Test 3: Mild weather, outdoor temp 15°C ---")
print_results(15)

-- Test 4: One zone needs more heat
print("--- Test 4: Living room needs more heat ---")
controller:update_zone_temperature("living_room", 19)  -- Below target
controller:update_zone_demand("living_room", 1.3)        -- Increase demand
print_results(5.0)

-- Test 5: Turn off some zones (e.g., night mode)
print("--- Test 5: Night mode - only bedroom_1 and bathroom active ---")
controller:set_zone_active("living_room", false)
controller:set_zone_active("bedroom_2", false)
controller:set_zone_active("kitchen", false)
print_results(0.0)

-- Test 6: Re-enable all zones and check status
print("--- Test 6: Full system status ---")
controller:set_zone_active("living_room", true)
controller:set_zone_active("bedroom_2", true)
controller:set_zone_active("kitchen", true)

local status = controller:get_status()
print(string.format("Current Flow Temperature: %.1f°C", status.current_flow_temp))
print(string.format("Target Room Temperature: %.1f°C", status.room_temp_target))
print(string.format("Total Active Area: %.1f sqm", status.total_area_sqm))
print(string.format("Total Heat Demand: %.0f W", status.total_demand_w))
print("\nZone Details:")
for zone_id, zone_info in pairs(status.zones) do
    print(string.format("  %s: %.1f sqm, Target: %.1f°C, Current: %s, Active: %s, Demand: %.0f W", 
        zone_id,
        zone_info.area_sqm,
        zone_info.temp_target,
        zone_info.current_temp and string.format("%.1f°C", zone_info.current_temp) or "N/A",
        zone_info.is_active and "Yes" or "No",
        zone_info.heat_demand_w))
end
print("")

-- Test 7: Simulate dynamic adjustment over time
print("--- Test 7: Dynamic simulation (outdoor temp changing) ---")
local outdoor_temps = {10, 5, 0, -5, -10, -5, 0, 5}
print("Simulating temperature changes throughout the day:\n")
for i, temp in ipairs(outdoor_temps) do
    local result = controller:calculate_flow_temperature(temp)
    print(string.format("Time %d: Outdoor %.1f°C -> Flow %.1f°C (Demand: %f W)", 
        i, temp, result.flow_temperature, result.total_demand_w))
end
print("")

-- Test 8: Adjust heating curve
print("--- Test 8: Testing different heating curve slopes ---")
local outdoor_temp = 0
print(string.format("Outdoor temperature: %.1f°C\n", outdoor_temp))

for slope = 1, 1.5, 0.1 do
    controller:set_curve_slope(slope)
    local result = controller:calculate_flow_temperature(outdoor_temp)
    print(string.format("Curve slope %.1f -> Flow temp: %.1f°C", slope, result.flow_temperature))
end
print("")

-- Test 9: Test with heating curve offset
print("--- Test 9: Testing heating curve offset ---")
controller:set_curve_slope(1.2)  -- Reset to default
controller:set_curve_offset(0)
local base_result = controller:calculate_flow_temperature(0)
print(string.format("Base (offset 0°C): Flow temp = %.1f°C", base_result.flow_temperature))

controller:set_curve_offset(2)
local offset_result = controller:calculate_flow_temperature(0)
print(string.format("With offset +2°C: Flow temp = %.1f°C", offset_result.flow_temperature))

controller:set_curve_offset(-2)
local offset_result2 = controller:calculate_flow_temperature(0)
print(string.format("With offset -2°C: Flow temp = %.1f°C", offset_result2.flow_temperature))
print("")

-- Test 10: Adjusting individual zone temperature targets
print("--- Test 10: Changing zone temperature targets ---")
print("Initial zone targets:")
local initial_status = controller:get_status()
for zone_id, zone_info in pairs(initial_status.zones) do
    print(string.format("  %s: %.1f°C", zone_id, zone_info.temp_target))
end

print("\nChanging bathroom to 24°C and bedroom_1 to 18°C...")
controller:set_zone_temp_target("bathroom", 24)
controller:set_zone_temp_target("bedroom_1", 18)

print("\nUpdated zone targets:")
local updated_status = controller:get_status()
for zone_id, zone_info in pairs(updated_status.zones) do
    print(string.format("  %s: %.1f°C", zone_id, zone_info.temp_target))
end

-- Set some current temperatures to show demand adjustment
controller:update_zone_temperature("bathroom", 22)    -- 2°C below target
controller:update_zone_temperature("bedroom_1", 18.5)   -- 0.5°C above target

local result_temp_targets = controller:calculate_flow_temperature(5)
print(string.format("\nWith all zones active (max target 24°C):"))
print(string.format("  Base flow temp: %.1f°C", result_temp_targets.base_flow_temperature))
print(string.format("  Final flow temp: %.1f°C (adjustment: %.2f)", 
    result_temp_targets.flow_temperature, 
    result_temp_targets.demand_adjustment))
print("")

-- Test 11: Effect of zone targets on base flow temperature
print("--- Test 11: Impact of zone targets on base flow temperature ---")
print("Testing at outdoor temp 5°C:\n")

-- Test with all zones active (bathroom at 24°C is highest)
controller:set_zone_active("living_room", true)
controller:set_zone_active("bedroom_1", true)
controller:set_zone_active("bedroom_2", true)
controller:set_zone_active("bathroom", true)
controller:set_zone_active("kitchen", true)
local all_zones = controller:calculate_flow_temperature(5)
print(string.format("All zones active (highest target: 24°C bathroom):"))
print(string.format("  Base flow temp: %.1f°C", all_zones.base_flow_temperature))

-- Test without bathroom (living room at 21°C is highest)
controller:set_zone_active("bathroom", false)
local no_bathroom = controller:calculate_flow_temperature(5.0)
print(string.format("\nBathroom OFF (highest target: 21°C living room):"))
print(string.format("  Base flow temp: %.1f°C", no_bathroom.base_flow_temperature))
print(string.format("  Difference: %.1f°C", all_zones.base_flow_temperature - no_bathroom.base_flow_temperature))

-- Test with only bedrooms (19°C and 18°C)
controller:set_zone_active("living_room", false)
controller:set_zone_active("kitchen", false)
controller:set_zone_active("bedroom_1", true)
controller:set_zone_active("bedroom_2", true)
local only_bedrooms = controller:calculate_flow_temperature(5)
print(string.format("\nOnly bedrooms (highest target: 19°C):"))
print(string.format("  Base flow temp: %.1f°C", only_bedrooms.base_flow_temperature))
print(string.format("  Difference from all zones: %.1f°C", all_zones.base_flow_temperature - only_bedrooms.base_flow_temperature))
print("")

print("=== Example completed ===")
