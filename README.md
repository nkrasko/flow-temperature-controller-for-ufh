# Flow Temperature Controller for Underfloor Heating

A Lua implementation of an intelligent flow temperature controller designed for underfloor heating systems. The controller calculates optimal liquid (water or glycol mixtures) flow temperatures based on outdoor temperature, zone demands, and heating curve types.

This controller is universal and can be used in wide range of application, thanks to Lua support for all possible architectures.

This controller is proved to be used with [Enapter Energy Managmement System Toolkit 3.0](https://handbook.enapter.com/software/gateway_software/#%F0%9F%9A%80-installation-guide).

## Features

- **🌥️ Weather Compensation**: Automatically adjusts flow temperature based on outdoor temperature using a heating curve
- **🏘️ Multi-Zone Management**: Supports multiple heating zones with individual area and demand settings
- **↕️ Demand-Based Adjustment**: Dynamically adjusts flow temperature based on actual heat demand from rooms
- **🌡️ Temperature Feedback**: Incorporates room temperature feedback for better control
- **⚙️ Configurable Parameters**: Fully configurable heating curves, limits, and zone characteristics

## How It Works

### Heating Curve Calculation

The controller supports three types of heating curves: **Linear**, **Logarithmic**, and **Exponential**.

#### Linear Curve (Default, Recommended)

```
Flow Temperature = Effective Target + (Base Outdoor Temp - Outdoor Temp) × Curve Slope + Offset
```

- **Constant response rate**: Same increase per degree of outdoor temperature drop
- **Best for**: Most standard installations, moderate insulation

#### Logarithmic Curve

```
Flow Temperature = Effective Target + Scaled_Log_Function × Max_Diff × Curve Slope + Offset
```

- **Aggressive**: More heat in general
- **Best for**: Poorly insulated buildings, cold climates, buildings with slow thermal response or for those who always "feel cold"

#### Exponential Curve

```
Flow Temperature = Effective Target + Scaled_Exp_Function × Max_Diff × Curve Slope + Offset
```

- **Gentle**: Less heat in general
- **Best for**: Well-insulated buildings, mild climates, modern buildings or for those who always "feel hot"

#### Curve Parameters

Where:
- **Effective Target**: The highest temperature target among all active zones (ensures all zones can reach their targets)
- **Curve Slope**: Determines overall heating intensity (default: 0.6, higher - more heat losses)
- **Curve Factor**: Controls curve aggressiveness for logarithmic/exponential (default: 0.5-4)
- **Offset**: Fixed adjustment to the curve (default: 0°C)

**Important**: The controller uses the **maximum temperature target** from all active zones to calculate the base flow temperature. This ensures that even the zone requiring the highest temperature can be satisfied. For example:
- If bathroom needs 24°C and bedroom needs 19°C, the base flow temperature is calculated using 24°C. If bathroom is turned off, the base flow temperature is recalculated using the next highest target (e.g., 21°C for living room)

This approach is optimal for underfloor heating systems where individual zones can control  valves on manifold if they reach target temperature.

### Demand Adjustment

The controller monitors all active zones and adjusts the flow temperature based on:
1. **Zone demand factors**: Manual or automatic adjustments per zone (0 to 2)
2. **Room temperature feedback**: Proportional adjustment based on temperature error
3. **Total heat demand**: Calculated from zone areas and demand factors

The controller uses a two-stage approach:

**Stage 1 - Base Flow Temperature** (from heating curve):
- Calculates using the highest temperature target among active zones
- Ensures all zones can potentially reach their individual targets
- Example: If bathroom needs 24°C and bedroom needs 19°C, uses 24°C in the heating curve

**Stage 2 - Demand Adjustment** (fine-tuning):
- Adjusts flow temperature ±5°C based on average demand across zones
- Considers individual zone temperature errors (target - current)
- Increases flow temp if zones are below target, decreases if above target
- This provides dynamic response without constantly changing zone valves

### Temperature Limits

- **Minimum Flow Temperature**: 25°C (configurable)
- **Maximum Flow Temperature**: 45°C (configurable, never change if you don't know what you are doing)
- **Base Outdoor Temperature**: 18°C (heating turns off above this)

## Installation

Copy `flow_temperature_controller.lua` to your project directory.

```lua
local FlowTemperatureController = require("flow_temperature_controller")
```

## Basic Usage

### 1. Create Controller Instance

```lua
-- Linear curve (default)
local controller = FlowTemperatureController:new({
    room_temp_target = 21,  -- Target room temperature (°C)
    min_flow_temp = 25, -- Minimum flow temperature (°C)
    base_outdoor_temp = 18, -- Outdoor temp at which heating stops (°C)
    design_outdoor_temp = -15,  -- Design outdoor temperature (°C)
    curve_type = "linear",  -- Curve type: "linear", "logarithmic", or "exponential"
    curve_slope = 0.6,  -- Heating curve slope
})

-- OR Logarithmic curve (more aggressive for cold climate)
local controller = FlowTemperatureController:new({
    room_temp_target = 21,
    curve_type = "logarithmic",
    curve_slope = 1.2,
    curve_factor = 2 -- Higher = more aggressive (range: 0.5-4)
})

-- OR Exponential curve (gentler at cold temps)
local controller = FlowTemperatureController:new({
    room_temp_target = 21.0,
    curve_type = "exponential",
    curve_slope = 1.2,
    curve_factor = 2, -- Higher = more gentle (range: 0.5-4)
})
```

### 2. Add Heating Zones

```lua
-- add_zone(zone_id, area_sqm, heat_demand_w_per_sqm, temp_target)
controller:add_zone("living_room", 35, 100, 21)
controller:add_zone("bedroom", 18, 90, 19)
controller:add_zone("bathroom", 8, 100, 23)
```

**Note:** Each zone can have its own temperature target. If not specified, it uses the global `room_temp_target` from the controller configuration.

If you have radiator heating - make it around 60 W/sqm, no other sources - 80-100 W/sqm

### 3. Calculate Flow Temperature

```lua
local outdoor_temp = 5  -- Current outdoor temperature in °C
local result = controller:calculate_flow_temperature(outdoor_temp)

print("Flow Temperature: " .. result.flow_temperature .. "°C")
print("Total Demand: " .. result.total_demand_w .. " W")
```

### 4. Update Zone States (Optional)

```lua
-- Set zone active/inactive (e.g., night mode, presence sensor, thermostat)
controller:set_zone_active("living_room", false)

-- Update zone demand factor (0.0 to 2.0)
controller:update_zone_demand("bedroom", 1.2)  -- Needs 20% more heat

-- Update current room temperature for feedback control
controller:update_zone_temperature("bedroom", 19.5)
```

## API Reference

### Constructor

**`FlowTemperatureController:new(config)`**

Creates a new controller instance.

**Parameters:**
- `config.room_temp_target` (number, default: 21.0): Target room temperature in °C
- `config.min_flow_temp` (number, default: 25.0): Minimum flow temperature in °C
- `config.max_flow_temp` (number, default: 45.0): Maximum flow temperature in °C
- `config.base_outdoor_temp` (number, default: 18.0): Outdoor temp where heating stops
- `config.design_outdoor_temp` (number, default: -15.0): Design outdoor temperature
- `config.curve_type` (string, default: "linear"): Curve type - "linear", "logarithmic", or "exponential"
- `config.curve_slope` (number, default: 1.2): Heating curve slope factor
- `config.curve_offset` (number, default: 0.0): Heating curve offset in °C
- `config.curve_factor` (number, default: 0.5): Factor for non-linear curves (0.5-4.0)

### Zone Management

**`controller:add_zone(zone_id, area_sqm, heat_demand_w_per_sqm, temp_target)`**

Adds a new heating zone.

**Parameters:**
- `zone_id` (string): Unique identifier for the zone
- `area_sqm` (number): Zone area in square meters
- `heat_demand_w_per_sqm` (number, default: 100): Base heat demand in W/sqm
- `temp_target` (number, optional): Target temperature for this zone in °C. If not specified, uses the global `room_temp_target`

**`controller:set_zone_active(zone_id, is_active)`**

Enables or disables a zone.

**`controller:update_zone_demand(zone_id, demand_factor)`**

Updates the demand factor for a zone (0.0 to 2.0).

**`controller:update_zone_temperature(zone_id, temperature)`**

Updates the current room temperature for a zone (for feedback control).

**`controller:set_zone_temp_target(zone_id, temp_target)`**

Sets a new temperature target for a specific zone.

### Calculation

**`controller:calculate_flow_temperature(outdoor_temp)`**

Calculates the required flow temperature.

**Parameters:**
- `outdoor_temp` (number): Current outdoor temperature in °C

**Returns:** Table with:
- `flow_temperature`: Calculated flow temperature in °C
- `base_flow_temperature`: Base temperature from heating curve
- `outdoor_temperature`: Input outdoor temperature
- `demand_adjustment`: Applied demand adjustment factor
- `total_demand_w`: Total heat demand in watts
- `total_area_sqm`: Total active area
- `active_zones`: Number of active zones

### Status and Information

**`controller:get_flow_temperature()`**

Returns the last calculated flow temperature.

**`controller:get_status()`**

Returns comprehensive system status including all zones.

**`controller:get_zones_info()`**

Returns detailed information about all zones.

### Curve Adjustment

**`controller:set_curve_slope(slope)`**

Adjusts the heating curve slope.

**`controller:set_curve_offset(offset)`**

Adjusts the heating curve offset.

**`controller:set_curve_type(curve_type)`**

Changes the heating curve type.

**Parameters:**
- `curve_type` (string): One of "linear", "logarithmic", or "exponential"

**`controller:set_curve_factor(factor)`**

Sets the curve factor for logarithmic and exponential curves.

**Parameters:**
- `factor` (number): Curve aggressiveness factor, typically 0.5-4.0
  - For logarithmic: Higher = more aggressive at cold temps
  - For exponential: Higher = gentler at cold temps

## Configuration Guide

### Heating Curve Slope

The curve slope determines how aggressively the flow temperature responds to outdoor temperature changes:

- **Lower slope (0.6-1.0)**: Gentler response, suitable for well-insulated buildings
- **Medium slope (1.0-1.3)**: Standard response for most buildings
- **Higher slope (1.3-1.6)**: More aggressive response for poorly insulated buildings

### Heating Curve Type Selection

Linear recommended form most applications.
Choose the appropriate curve type based on building characteristics and climate:

**☀️ Mild Climate** - Expnonential Curve
**🥶 Cold Climate** - Logarithmic Curve

### Curve Factor Tuning

For logarithmic and exponential curves, the `curve_factor` controls aggressiveness:

**Logarithmic Curve:**
- **0.5-1**: Gentle, close to linear
- **1.5-2.5**: Moderate, good for most cold climate applications
- **3.0-4**: Very aggressive, for extreme cold or poor insulation

**Exponential Curve:**
- **0.5-1**: Minimal effect, close to linear
- **1.5-2.5**: Moderate, good for well-insulated buildings
- **3.0-4**: Strong reduction at cold temps, for passive houses

### Zone Temperature Targets

Different rooms typically have different comfort requirements:

- **Living rooms**: 19-22°C
- **Bedrooms**: 19-21°C (cooler for better sleep)
- **Bathrooms**: 22-23°C (warmer for comfort)
- **Kitchen**: 18-20°C (heat from cooking is also heat)
- **Hall / Thoroughfare**: 18-19°C
- **Home office**: 20-22°C
- **Children's rooms**: 19-20°C

These are my general guidelines - adjust based on personal preference and local climate.

### Heat Demand per Square Meter

These values depend on:
- Codes
- Building insulation quality
- Ceiling height
- Window area
- Climate zone
- Desired comfort level
- Local construction codes

If you have radiator heating (or other fast heating options) then start at 65 W/sqm, if only underfloor heating - 100 W/sqm.

### Maximum Flow Temperature

For underfloor heating maximum temperature of the liquid should not be more than 45°C, floor surface temperature must be in the range of 26°C to 29°C.

## Example Scenarios

### Scenario 1: Basic Operation

```lua
local controller = FlowTemperatureController:new({})
controller:add_zone("dining", 50, 100)

-- At 5°C outdoor temperature
local result = controller:calculate_flow_temperature(5)
```

### Scenario 2: Night Setback

```lua
-- During day: all zones active
controller:set_zone_active("living_room", true)
controller:set_zone_active("bedroom", true)

-- During night: reduce living room
controller:set_zone_active("living_room", false)
controller:update_zone_demand("bedroom", 0.8)  -- Lower demand
```

### Scenario 3: Weather Compensation

```lua
-- Cold morning: -5°C
local morning = controller:calculate_flow_temperature(-5)

-- Warm afternoon: 15°C
local afternoon = controller:calculate_flow_temperature(15)
```

### Scenario 4: Zone-Specific Adjustment

```lua
-- Living room feels too cold
controller:update_zone_temperature("living_room", 19)  -- Below target
-- Controller will automatically increase demand for this zone
```

### Scenario 5: Individual Room Temperature Preferences

```lua
-- Set different comfort levels for different rooms
controller:add_zone("living_room", 35.0, 100, 21)    -- 21°C
controller:add_zone("bedroom_main", 18.0, 90, 19)    -- 19°C
controller:add_zone("bedroom_child", 15.0, 90, 20)   -- 20°C
controller:add_zone("bathroom", 8.0, 110, 23)        -- 23°C
controller:add_zone("home_office", 12.0, 95, 21)     -- 21°C

-- Later adjust bathroom during morning hours
controller:set_zone_temp_target("bathroom", 24)      -- Even warmer
```

### Scenario 6: Night Mode with Temperature Optimization

```lua
-- During day: all zones active at 5°C outdoor
local day_result = controller:calculate_flow_temperature(5)
-- Base flow temp: 37.6°C (based on bathroom's 24°C target)

-- Night: turn off living room and bathroom
controller:set_zone_active("living_room", false)
controller:set_zone_active("bathroom", false)

-- Only bedrooms active (highest target 20°C)
local night_result = controller:calculate_flow_temperature(5)
-- Base flow temp: 34.6°C (based on bedroom's 20°C target)
-- Energy savings: 3°C lower flow temperature reduces energy consumption
```

### Scenario 7: Choosing the Right Curve Type

```lua
-- Scenario A: Old building in cold climate (East Europe, Russia)
-- Problem: Feels cold during temperature drops, slow to warm up
local controller_a = FlowTemperatureController:new({
    curve_type = "logarithmic",  -- Aggressive at cold temps
    curve_factor = 2.5,           -- Strong response
    curve_slope = 1.3
})

-- Scenario B: Modern well-insulated building (Germany, Passive House)
-- Problem: Overheats in between seasons seasons, wastes energy
local controller_b = FlowTemperatureController:new({
    curve_type = "exponential",   -- Gentle at cold temps
    curve_factor = 2.0,            -- Insulation is very good
    curve_slope = 1.0
})

-- Scenario C: Standard building, moderate climate (Yerevan)
-- Problem: None, just needs reliable heating
local controller_c = FlowTemperatureController:new({
    curve_type = "linear",        -- Predictable response
    curve_slope = 1.2
})
```

It is also possible to select perfect curve based on season or month or based on solar irradiance forecasts.

## Integration with Building Management Systems

The controller can be integrated with:

1. **Outdoor temperature sensors**: Feed `outdoor_temp` to `calculate_flow_temperature()`
2. **Room thermostats**: Use `update_zone_temperature()` for feedback
3. **Presence sensors**: Use `set_zone_active()` to disable empty zones
4. **Time schedules**: Adjust `demand_factor` based on time of day
5. **Weather forecasts**: Pre-adjust heating curve based on predictions
6. **Energy costs / Tarriffs**: Increase demamd factor if price is cheaper and decrease when higher.

## Optimization Tips

1. **Start with standard values** and adjust gradually based on comfort
2. **Monitor energy consumption** while adjusting curve parameters
3. **Use zone temperature feedback** to fine-tune individual rooms
4. **Adjust curve slope seasonally** if needed (lower in mild weather)
5. **Log and analyze** outdoor vs flow temperatures to optimize curve (Use Enapter EMS for this, for example)
