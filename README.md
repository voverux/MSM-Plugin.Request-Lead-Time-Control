# MSM Plugin :: Request Lead Time Control

This plugin extends MSM functionality to control request start time lead period (minimum time required until the request could be started).

# !!! IMPORTANT !!!:
Since MSM system doesn't have any MSM request actions data web services by default, MSM Web Service Extensions are required (not included here).
Only if/when new appropriate api methods will be implemented in MSM system this package could be used in your systems.
Please feel free to contact Marval Baltic in case you would like to see this plugin working.

## Compatible Versions

| Plugin  | MSM             |
|---------|-----------------|
| 1.0.0   | 14.4.0 - 14.7.0 |

## Installation

Please see your MSM documentation for information on how to install plugins.

Once the plugin has been installed as plugin parameters you need to specify:
* Rules Action Message - Name or ID of MSM Action Message to be used as container for plugin rules stored as json object.
* MSM WSE Address - MSM Web Service Extensions (not available publicly) address
* MSM WSE User Name - MSM Web Service Extensions user name (encrypted)
* MSM WSE Password - MSM Web Service Extensions password (encrypted)

## Usage

The plugin is automatically checking lead times configured in Request Action Message on every Request update.

## Contributing

 Any feedback or improvement suggestion is very welcome.