# <img align="left" src="media/edisiogateway_logo.png"> Vera-Plugin-EdisioGateway

**Control your edisio devices from your Vera**


Designed for [Vera Control, Ltd.](http://getvera.com) Home Controllers (UI5 & UI7) and [openLuup](https://github.com/akbooer/openLuup).


## Introduction

The Edisio Gateway plugin provides the ability to control your edisio devices from your Vera.
More informations on edisio here : http://www.edisio.com/

The plugin creates new devices (switches, dimmers, sensors, ...) in your Vera corresponding to your edisio network.
These devices appear in the user interface as the others (e.g. Z-wave devices) and can be used in scenes.

For specific manipulations (pair, association), the plugin has its own User Interface.


## Requirements

Plug the edisio USB dongle into an Vera's USB port.


## Installation

After installing the plugin, an "Edisio Gateway" device will be created.
http://apps.mios.com/plugin.php?id=8651

Assign the serial port of the dongle to the plugin : go to "Apps/Develop Apps/Serial Port Configuration" and select from "Used by device" drop down list the "Edisio Gateway".
Set the following parameters :

```
Baud Rate : 9600
Data bits : 8
Parity : none
Stop bits : 1
```

You will certainly need to set the baud parameter on another value, save, and then on 9600. It seems that default values are not saved


## Learn

Vera must learn the devices from your edisio network.

1. Press (physically) the "R" button on the edisio device you want to add (you can do this on several devices at same time). For a remote, click on the buttons you want to learn.
1. Go in tab "Discovered" in the "Edisio Gateway" plugin.
1. Select all the checkboxes corresponding to the channels which you want to add, and click on the "Learn" button.


After some seconds (reload of the Luup engine), the new devices corresponding to your selected edisio devices, should appear in the user interface.


## Teach in

If the edisio device is a receiver, that device must be "paired" with the Vera.

1. Go in tab "Devices" in the "Edisio Gateway" plugin.
1. Click on "Actions" button of your edisio receiver, and click on "Teach in" button.
1. After several "beep" sounds, a continuous "beep" sound indicates the pairing.

After the pairing, you should be able to control this edisio receiver from the corresponding device in the user interface.


## Association

You can define a link between your edisio device and another device in your Vera. It allows you to bind devices without having to use scenes.

From the tab "Devices" in the plugin, click on the action "Associate" of the device you wish to link.
Then select the compatible devices and validate.

Association means that changes on the edisio device will be passed on the associated device (e.g. if the edisio device is switched on at 60%, the associated device is switched on at 60% too).


## Todo

- [X] Association with HA devices
- [X] Compatibility with receiver with more than one output
- [X] Compatibility with motion sensor
- [ ] Poll edisio receivers.
- [ ] Manage edisio custom parameters (e.g. minimum and maximum light intensity for dimmer device)
- [ ] Manage farhenheit, depending of the Vera configuration.
- [ ] Discovered edisio device to ignore
