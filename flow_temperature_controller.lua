-- Copyright 2025 Nikolay V. Krasko
-- Licensed under GNU GPLv3
-- Flow Temperature Controller for Underfloor Heating
-- Calculates optimal boiler flow temperature based on outdoor temperature and zone demands

FlowTemperatureController = {}
FlowTemperatureController.__index = FlowTemperatureController

-- Constructor
function FlowTemperatureController:new(config)
    local obj = setmetatable({}, FlowTemperatureController)

    -- Configuration parameters
    obj.room_temp_target = config.room_temp_target or 21  -- Target room temperature (°C)
    obj.min_flow_temp = config.min_flow_temp or 25  -- Minimum flow temperature (°C)
    obj.max_flow_temp = config.max_flow_temp or 45  -- Maximum flow temperature for UFH (°C)
    obj.base_outdoor_temp = config.base_outdoor_temp or 18  -- Outdoor temp at which heating turns off (°C)
    obj.design_outdoor_temp = config.design_outdoor_temp or -15 -- Design outdoor temperature (°C)

    -- Heating curve parameters
    obj.curve_type = config.curve_type or "linear"  -- "linear", "logarithmic", or "exponential"
    obj.curve_slope = config.curve_slope or 0.6 -- Heating curve slope factor
    obj.curve_offset = config.curve_offset or 0 -- Offset for curve adjustment (°C)

    -- Additional parameters for non-linear curves
    obj.curve_factor = config.curve_factor or 0.5 -- Factor for logarithmic/exponential curves

    -- Heating zones
    obj.zones = {}

    -- System state
    obj.current_outdoor_temp = nil
    obj.calculated_flow_temp = obj.min_flow_temp

    return obj
end

-- Add a heating zone
function FlowTemperatureController:add_zone(zone_id, area_sqm, heat_demand_w_per_sqm, temp_target)
    self.zones[zone_id] = {
        area = area_sqm or 0,
        heat_demand_base = heat_demand_w_per_sqm or 100,  -- Zone base heat demand W/m²
        temp_target = temp_target or self.room_temp_target, -- Zone target temp (°C)
        is_active = true, -- Can be set by thermostat
        current_temp = nil,
        demand_factor = 1  -- Multiplier for current demand (0 to 2)
    }
end

-- Update zone demand factor (e.g., from thermostat feedback)
function FlowTemperatureController:update_zone_demand(zone_id, demand_factor)
    if self.zones[zone_id] then
        self.zones[zone_id].demand_factor = math.max(0, math.min(2, demand_factor))
    end
end

-- Set zone active/inactive state
function FlowTemperatureController:set_zone_active(zone_id, is_active)
    if self.zones[zone_id] then
        self.zones[zone_id].is_active = is_active
    end
end

-- Update zone current temperature
function FlowTemperatureController:update_zone_temperature(zone_id, temperature)
    if self.zones[zone_id] then
        self.zones[zone_id].current_temp = temperature
    end
end

-- Set zone temperature target
function FlowTemperatureController:set_zone_temp_target(zone_id, temp_target)
    if self.zones[zone_id] then
        self.zones[zone_id].temp_target = temp_target
    end
end

-- Calculate effective target temperature from active zones
function FlowTemperatureController:calculate_effective_target_temp()
    local max_target = self.room_temp_target
    local total_weighted_target = 0
    local total_weight = 0
    local has_active_zones = false

    -- Find maximum target and calculate weighted average
    for zone_id, zone in pairs(self.zones) do
        if zone.is_active then
            has_active_zones = true
            -- Use maximum target to ensure all zones can reach their target
            if zone.temp_target > max_target then
                max_target = zone.temp_target
            end
            -- Also calculate area-weighted average
            local weight = zone.area * zone.demand_factor
            total_weighted_target = total_weighted_target + (zone.temp_target * weight)
            total_weight = total_weight + weight
        end
    end

    -- If no active zones, use global target
    if not has_active_zones then
        return self.room_temp_target
    end

    -- Use maximum target to ensure all zones can be satisfied
    -- (TODO: weighted average for more economical approach)
    return max_target
end

-- Calculate base flow temperature from heating curve
function FlowTemperatureController:calculate_base_flow_temp(outdoor_temp)
    -- If outdoor temp is above base temp, no heating needed
    if outdoor_temp >= self.base_outdoor_temp then
        return self.min_flow_temp
    end

    -- Get effective target temperature from active zones
    local effective_target = self:calculate_effective_target_temp()

    -- Calculate temperature difference from base
    local temp_diff = self.base_outdoor_temp - outdoor_temp

    local flow_temp

    if self.curve_type == "logarithmic" then
        -- Logarithmic curve: more aggressive at colder temps, gentler at warmer temps
        -- Formula: flow_temp = effective_target + curve_slope × log(curve_factor × temp_diff + 1) / log(curve_factor + 1) × max_diff + offset
        local max_diff = self.base_outdoor_temp - self.design_outdoor_temp
        local normalized_diff = temp_diff / max_diff  -- 0 to 1

        -- Apply logarithmic scaling
        local log_value = math.log(self.curve_factor * normalized_diff + 1) / math.log(self.curve_factor + 1)

        -- Scale to temperature range
        flow_temp = effective_target + (log_value * max_diff * self.curve_slope) + self.curve_offset

    elseif self.curve_type == "exponential" then
        -- Exponential curve: gentler at colder temps, more aggressive at warmer temps
        -- Formula: flow_temp = effective_target + curve_slope × (exp(curve_factor × normalized_diff) - 1) / (exp(curve_factor) - 1) × max_diff + offset
        local max_diff = self.base_outdoor_temp - self.design_outdoor_temp
        local normalized_diff = temp_diff / max_diff  -- 0 to 1

        -- Apply exponential scaling
        local exp_value = (math.exp(self.curve_factor * normalized_diff) - 1) / (math.exp(self.curve_factor) - 1)

        -- Scale to temperature range
        flow_temp = effective_target + (exp_value * max_diff * self.curve_slope) + self.curve_offset

    else
        -- Linear curve (default): constant rate of change
        -- Apply heating curve: flow_temp = effective_target + (temp_diff * curve_slope) + offset
        flow_temp = effective_target + (temp_diff * self.curve_slope) + self.curve_offset
    end

    -- Clamp to min/max values
    flow_temp = math.max(self.min_flow_temp, math.min(self.max_flow_temp, flow_temp))

    return flow_temp
end

-- Calculate total heat demand from all active zones
function FlowTemperatureController:calculate_total_demand()
    local total_demand_w = 0
    local total_active_area = 0
    local active_zones_count = 0

    for zone_id, zone in pairs(self.zones) do
        if zone.is_active then
            local zone_demand = zone.area * zone.heat_demand_base * zone.demand_factor
            total_demand_w = total_demand_w + zone_demand
            total_active_area = total_active_area + zone.area
            active_zones_count = active_zones_count + 1
        end
    end

    return {
        total_power_w = total_demand_w,
        total_area_sqm = total_active_area,
        active_zones = active_zones_count,
        avg_demand_w_per_sqm = total_active_area > 0 and (total_demand_w / total_active_area) or 0
    }
end

-- Calculate demand adjustment factor based on zone feedback
function FlowTemperatureController:calculate_demand_adjustment()
    local adjustment_sum = 0
    local zone_count = 0

    for zone_id, zone in pairs(self.zones) do
        if zone.is_active then
            -- If zone has current temperature, calculate error
            if zone.current_temp then
                local temp_error = zone.temp_target - zone.current_temp
                -- Adjust demand based on temperature error (proportional)
                local error_adjustment = temp_error * 0.15  -- 0.15 = proportional gain
                adjustment_sum = adjustment_sum + (zone.demand_factor + error_adjustment)
            else
                adjustment_sum = adjustment_sum + zone.demand_factor
            end
            zone_count = zone_count + 1
        end
    end

    if zone_count == 0 then
        return 1
    end

    local avg_adjustment = adjustment_sum / zone_count
    -- Clamp adjustment factor to reasonable range
    return math.max(0.5, math.min(1.5, avg_adjustment))
end

-- Main calculation function
function FlowTemperatureController:calculate_flow_temperature(outdoor_temp)
    self.current_outdoor_temp = outdoor_temp

    -- Calculate base flow temperature from heating curve
    local base_flow_temp = self:calculate_base_flow_temp(outdoor_temp)

    -- Get demand information
    local demand_info = self:calculate_total_demand()

    -- Calculate demand adjustment
    local demand_adjustment = self:calculate_demand_adjustment()

    -- Adjust flow temperature based on demand
    -- If demand is higher, increase flow temp; if lower, decrease it
    local adjusted_flow_temp = base_flow_temp + ((demand_adjustment - 1) * 5)

    -- Clamp to limits
    adjusted_flow_temp = math.max(self.min_flow_temp, math.min(self.max_flow_temp, adjusted_flow_temp))

    self.calculated_flow_temp = adjusted_flow_temp

    return {
        flow_temperature = adjusted_flow_temp,
        base_flow_temperature = base_flow_temp,
        outdoor_temperature = outdoor_temp,
        demand_adjustment = demand_adjustment,
        total_demand_w = demand_info.total_power_w,
        total_area_sqm = demand_info.total_area_sqm,
        active_zones = demand_info.active_zones
    }
end

-- Get current flow temperature
function FlowTemperatureController:get_flow_temperature()
    return self.calculated_flow_temp
end

-- Get status information
function FlowTemperatureController:get_status()
    local demand_info = self:calculate_total_demand()

    return {
        current_flow_temp = self.calculated_flow_temp,
        outdoor_temp = self.current_outdoor_temp,
        room_temp_target = self.room_temp_target,
        total_demand_w = demand_info.total_power_w,
        total_area_sqm = demand_info.total_area_sqm,
        active_zones = demand_info.active_zones,
        zones = self:get_zones_info()
    }
end

-- Get information about all zones
function FlowTemperatureController:get_zones_info()
    local zones_info = {}
    for zone_id, zone in pairs(self.zones) do
        zones_info[zone_id] = {
            area_sqm = zone.area,
            is_active = zone.is_active,
            temp_target = zone.temp_target,
            current_temp = zone.current_temp,
            demand_factor = zone.demand_factor,
            heat_demand_w = zone.area * zone.heat_demand_base * zone.demand_factor
        }
    end
    return zones_info
end

-- Adjust heating curve slope
function FlowTemperatureController:set_curve_slope(slope)
    self.curve_slope = slope
end

-- Adjust heating curve offset
function FlowTemperatureController:set_curve_offset(offset)
    self.curve_offset = offset
end

-- Set heating curve type
function FlowTemperatureController:set_curve_type(curve_type)
    if curve_type == "linear" or curve_type == "logarithmic" or curve_type == "exponential" then
        self.curve_type = curve_type
    else
        error("Invalid curve type. Must be 'linear', 'logarithmic', or 'exponential'")
    end
end

-- Set curve factor (for logarithmic and exponential curves)
function FlowTemperatureController:set_curve_factor(factor)
    self.curve_factor = factor
end

return FlowTemperatureController
