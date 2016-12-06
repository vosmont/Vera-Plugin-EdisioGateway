//# sourceURL=J_EdisioGateway1.js

/**
 * This file is part of the plugin EdisioGateway.
 * https://github.com/vosmont/Vera-Plugin-EdisioGateway
 * Copyright (c) 2016 Vincent OSMONT
 * This code is released under the MIT License, see LICENSE.
 */


/**
 * UI5 compatibility with JavaScript API for UI7
 * http://wiki.micasaverde.com/index.php/JavaScript_API
 */
( function( $ ) {
	if ( !window.Utils ) {
		window.Utils = {
			logError: function( message ) {
				console.error( message );
			},
			logDebug: function( message ) {
				console.info( message );
			}
		};
	}
	if ( !window.api ) {
		window.api = {
			version: "UI5",
			API_VERSION: 6,

			getCommandURL: function() {
				return command_url;
			},
			getDataRequestURL: function() {
				return data_request_url;
			},
			getSendCommandURL: function() {
				return data_request_url.replace('port_3480/data_request','port_3480');
			},

			getListOfDevices: function() {
				return jsonp.ud.devices;
			},
			getRoomObject: function( roomId ) {
				roomId = roomId.toString();
				for ( var i = 0; i < jsonp.ud.rooms.length; i++ ) {
					var room = jsonp.ud.rooms[ i ];
					if ( room.id.toString() === roomId ) {
						return room;
					}
				}
			},
			setCpanelContent: function( html ) {
				set_panel_html( html );
			},
			getDeviceStateVariable: function( deviceId, service, variable, options ) {
				return get_device_state( deviceId, service, variable, ( options.dynamic === true ? 1: 0 ) );
			},
			setDeviceStateVariable: function( deviceId, service, variable, value, options ) {
				set_device_state( deviceId, service, variable, value, ( options.dynamic === true ? 1: 0 ) );
			},
			setDeviceStateVariablePersistent: function( deviceId, service, variable, value, options ) {
				set_device_state( deviceId, service, variable, value, 0 );
			},
			performActionOnDevice: function (deviceId, service, action, options) {
				var query = "id=lu_action&DeviceNum=" + deviceId + "&serviceId=" + service + "&action=" + action;
				$.each( options.actionArguments, function( key, value ) {
					query += "&" + key + "=" + value;
				});
				$.ajax( {
					url: data_request_url + query,
					success: function( data, textStatus, jqXHR ) {
						if ( $.isFunction( options.onSuccess ) ) {
							options.onSuccess( {
								responseText: jqXHR.responseText,
								status: jqXHR.status
							} );
						}
					},
					error: function( jqXHR, textStatus, errorThrown ) {
						if ( $.isFunction( options.onFailure ) ) {
							options.onFailure( {
								responseText: jqXHR.responseText,
								status: jqXHR.status
							} );
						}
					}
				});
			},
			registerEventHandler: function( eventName, object, functionName ) {
				// Not implemented in UI5
			},

			showLoadingOverlay: function() {
				if ( $.isFunction( show_loading ) ) {
					show_loading();
				}
				return $.Deferred().resolve();
			},
			hideLoadingOverlay: function() {
				if ( $.isFunction( hide_loading ) ) {
					hide_loading();
				}
				return true;
			},
			showCustomPopup: function( content, opt ) {
				content = content.replace( "<br\>", "\n" )
				if (opt.category && (opt.category == "confirm")) {
					if ( confirm( content ) ) {
						if ( $.isFunction( opt.onSuccess ) ) {
							opt.onSuccess();
						}
					} else {
						if ( $.isFunction( opt.onCancel ) ) {
							opt.onCancel();
						}
					}
				} else {
					alert( content )
					if ( $.isFunction( opt.onSuccess ) ) {
						opt.onSuccess();
					}
				}
			},

			getVersion: function() {
				return api.API_VERSION;
			},
			requiresVersion: function( minVersion, opt_fnFailure ) {
				console.log( "minVersion:", minVersion, "API Version:", api.API_VERSION );
				if ( api.API_VERSION < parseInt( minVersion, 10 ) ) {
					if ( $.isFunction( opt_fnFailure ) ) {
						return opt_fnFailure( api.API_VERSION );
					} else {
						Utils.logError( "WARNING ! This plugin requires at least API version " + minVersion + " !" );
					}
				}
			}
		};
	}
	// UI7 fix
	Utils.getDataRequestURL = function() {
		var dataRequestURL = api.getDataRequestURL();
		if ( dataRequestURL.indexOf( "?" ) === -1 ) {
			dataRequestURL += "?";
		}
		return dataRequestURL;
	};
	// Custom CSS injection
	Utils.injectCustomCSS = function( nameSpace, css ) {
		if ( $( "#custom-css-" + nameSpace ).size() === 0 ) {
			Utils.logDebug( "Injects custom CSS for " + nameSpace );
			var pluginStyle = $( '<style id="custom-css-' + nameSpace + '">' );
			pluginStyle
				.text( css )
				.appendTo( "head" );
		} else {
			Utils.logDebug( "Injection of custom CSS has already been done for " + nameSpace );
		}
	};
	Utils.performActionOnDevice = function( deviceId, service, action, actionArguments ) {
		var d = $.Deferred();
		try {
			api.performActionOnDevice( deviceId, service, action, {
				actionArguments: actionArguments,
				onSuccess: function( response ) {
					var result = JSON.parse( response.responseText );
					if ( !$.isPlainObject( result )
						|| !$.isPlainObject( result[ "u:" + action + "Response" ] )
						|| (
							( result[ "u:" + action + "Response" ].OK !== "OK" )
							&& ( typeof( result[ "u:" + action + "Response" ].JobID ) === "undefined" )
						)
					) {
						Utils.logError( "[Utils.performActionOnDevice] ERROR on action '" + action + "': " + response.responseText );
						d.reject();
					} else {
						d.resolve();
					}
				},
				onFailure: function( response ) {
					Utils.logDebug( "[Utils.performActionOnDevice] ERROR(" + response.status + "): " + response.responseText );
					d.reject();
				}
			} );
		} catch( err ) {
			Utils.logError( "[Utils.performActionOnDevice] ERROR: " + JSON.parse( err ) );
			d.reject();
		}
		return d.promise();
	}

} ) ( jQuery );


var EdisioGateway = ( function( api, $ ) {
	var _uuid = "f3737884-38bd-4d9b-983d-3fafac1ce9b4";
	var EDISIOGATEWAY_SID = "urn:upnp-org:serviceId:EdisioGateway1";
	var EDISIODEVICE_SID = "urn:upnp-org:serviceId:EdisioDevice1";
	var _deviceId = null;
	var _registerIsDone = false;
	var _lastUpdate = 0;
	var _indexChannels = {};
	var _selectEdisioId = "";
	var _formerScrollTopPosition = 0;

	var _terms = {
		"ConfirmationTeachInReceiver": "\
<b>Do you want to teach in (pair) this device ?</b><br/><br/>\
If you confirm, the edisio receiver should emit several \"beep\" sounds and then a continuous \"beep\".<br/><br/>\
In case of problem, you can retry or pair manually your Vera with the edisio receiver:<br/>\
- Press 1 time R pairing button (or several times depending the channel you want to pair).<br/>\
- Click on the button created in Vera UI for this receiver.<br/>\
- Press 1 time R button to confirm the pairing.\
",

		"ConfirmationClearingReceiver": "\
<b><font color=\"red\">Do you want to clear this device ?</font></b><br/><br/>\
All the channels will be erased, and paired edisio devices will be forgotten (<b>including those paired manually outside the Vera</b>)",

		"ExplanationKnownDevices": "\
TODO",

		"ExplanationAssociation": "\
Select the devices that you want to associate with this edisio device. Only compatible devices are shown.<br/>\
Association means that changes on the edisio device will be passed on the associated device (e.g. if the edisio device is switched on at 60%, the associated device is switched on at 60% too).<br/><br/>\
You can also associate with a scene.",

		"ExplanationDiscoveredDevices": "\
You will find in this panel all the edisio devices, not already known (learned), that have been seen by your Vera on the edisio network.<br/><br/>\
Select the channels of the edisio devices, choose the type of device that you want to create in your Vera, and then click on \"Learn\"."
/*<br/><br/>\
You can also select the channels of the edisio devices that you want to ignore : they will no more be displayed in this panel."*/,

		"WaitReload": "\
Devices have been created... wait until the reload of Luup engine",

		"NoDevice": "\
There's no edisio device.",

		"NoError": "\
There's no error."
	};
	_terms[ DEVICETYPE_TEMPERATURE_SENSOR ] = "Temperature sensor";
	_terms[ DEVICETYPE_MOTION_SENSOR ] = "Motion sensor";
	_terms[ DEVICETYPE_DOOR_SENSOR ] = "Door sensor";
	_terms[ DEVICETYPE_BINARY_LIGHT ] = "Switch";
	_terms[ DEVICETYPE_DIMMABLE_LIGHT ] = "Dimmable Switch";
	_terms[ DEVICETYPE_WINDOW_COVERING ] = "Window Covering";

	function _T( t ) {
		var v =_terms[ t ];
		if ( v ) {
			return v;
		}
		return t;
	}

	// Inject plugin specific CSS rules
	// http://www.utf8icons.com/
	Utils.injectCustomCSS( "edisiogateway", '\
.edisiogateway-panel { position: relative; padding: 5px; }\
.edisiogateway-panel label { font-weight: normal }\
.edisiogateway-panel .icon { vertical-align: middle; }\
.edisiogateway-panel .icon.big { vertical-align: sub; }\
.edisiogateway-panel .icon:before { font-size: 15px; }\
.edisiogateway-panel .icon.big:before { font-size: 30px; }\
.edisiogateway-panel .icon-menu:before { content: "\\25BE"; }\
.edisiogateway-panel .icon-ok:before { content: "\\2713"; }\
.edisiogateway-panel .icon-help:before { content: "\\2753"; }\
.edisiogateway-panel .icon-cancel:before { content: "\\2718"; }\
.edisiogateway-panel .icon-teach:before { content: "\\270D"; }\
.edisiogateway-panel .icon-ignore:before { content: "\\2718"; }\
.edisiogateway-panel .icon-refresh:before { content: "\\267B"; }\
.edisiogateway-panel .icon-temperature:before { content: "\\2103"; }\
.edisiogateway-panel .icon-motion:before { content: "\\2103"; }\
.edisiogateway-panel .icon-door:before { content: "\\25AF"; }\
.edisiogateway-panel .icon-button:before { content: "\\25A3"; }\
.edisiogateway-panel .icon-light:before { content: "\\25CF"; }\
.edisiogateway-panel .icon-dimmable:before { content: "\\25D0"; }\
.edisiogateway-panel .icon-shutter:before { content: "\\25A4"; }\
.edisiogateway-hidden { display: none; }\
.edisiogateway-error { color:red; }\
.edisiogateway-header { margin: 10px; font-size: 1.1em; font-weight: bold; }\
.edisiogateway-explanation { margin: 5px; padding: 5px; border: 1px solid; background: #FFFF88}\
.edisiogateway-toolbar { height: 25px; text-align: right; margin: 5px; }\
.edisiogateway-toolbar button { display: inline-block; }\
.edisiogateway-association-room { font-weight: bold; width: 100%; background: #ccc; }\
div.edisiogateway-association { padding-left: 20px; }\
div.edisiogateway-association label span { padding: 4px 0 0 2px; }\
span.edisiogateway-association { margin-right: 5px; }\
span.edisiogateway-association span { padding: 1px; }\
.edisiogateway-association-device .edisio-short-press { color: white; background: orange; border: 1px solid orange; }\
.edisiogateway-association-device .edisio-long-press  { color: white; background: red; border: 1px solid red; }\
.edisiogateway-association-scene .edisio-short-press  { color: white; background: blue; border: 1px solid blue; }\
.edisiogateway-association-scene .edisio-long-press   { color: white; background: green; border: 1px solid green; }\
.edisiogateway-association-edisiodevice .edisio-short-press  { color: white; background: purple; border: 1px solid purple; }\
.edisio-short-press {}\
.edisio-long-press { border: red; }\
.edisiogateway-device-channels { margin-left: 10px; }\
.edisiogateway-device-channel { padding-right: 5px; white-space: nowrap; }\
.edisiogateway-devices table { width: 100%; border: black 2px solid }\
.edisiogateway-devices th { text-align: center; background-color: #ccc; font-size: 1.2em; padding: 2px; border: black 2px solid }\
.edisiogateway-devices td { padding: 5px; border: 1px solid #ccc; border: black 1px solid }\
.edisiogateway-devices .description { font-style: italic; }\
#edisiogateway-device-actions { position: absolute; background: #FFF; border: 2px solid #AAA; white-space: nowrap; }\
#edisiogateway-device-actions td { padding: 5px; }\
#edisiogateway-device-actions button { display: inline-block; margin: 2px; }\
#edisiogateway-device-association {\
	position: absolute; top: 0px; left: 0px;\
	width: 100%;\
	background: #FFF; border: 2px solid #AAA;\
}\
#edisiogateway-device-params {\
	position: absolute; top: 0px; left: 0px;\
	width: 100%;\
	background: #FFF; border: 2px solid #AAA;\
}\
#edisiogateway-donate { text-align: center; width: 70%; margin: auto; }\
#edisiogateway-donate form { height: 50px; }'
	);

	/**
	 * Get informations on edisio devices
	 */
	function _getDevicesInfosAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_EdisioGateway&command=getDevicesInfos&output_format=json#",
			dataType: "json"
		} )
		.done( function( devicesInfos ) {
			api.hideLoadingOverlay();
			if ( $.isPlainObject( devicesInfos ) ) {
				d.resolve( devicesInfos );
			} else {
				Utils.logError( "No devices infos" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get edisio devices infos error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 *
	 */
	function _convertTimestampToLocaleString( timestamp ) {
		if ( typeof( timestamp ) === "undefined" ) {
			return "";
		}
		var t = new Date( parseInt( timestamp, 10 ) * 1000 );
		var localeString = t.toLocaleString();
		return localeString;
	}

	/**
	 *
	 */
	function _onDeviceStatusChanged( deviceObjectFromLuStatus ) {
		if ( deviceObjectFromLuStatus.id == _deviceId ) {
			for ( i = 0; i < deviceObjectFromLuStatus.states.length; i++ ) {
				if ( deviceObjectFromLuStatus.states[i].variable == "LastUpdate" ) {
					if ( _lastUpdate !== deviceObjectFromLuStatus.states[ i ].value ) {
						_lastUpdate = deviceObjectFromLuStatus.states[ i ].value;
						_drawDevicesList();
						_drawDiscoveredDevicesList();
					}
				} else if ( deviceObjectFromLuStatus.states[i].variable == "LastDiscovered" ) {
					// TODO : afficher bouton reload
				}
			}
		}
	}

	// *************************************************************************************************
	// edisio devices
	// *************************************************************************************************

	/**
	 * Draw and manage edisio device list
	 */
	function _drawDevicesList() {
		if ( $( "#edisiogateway-known-devices" ).length === 0 ) {
			return;
		}
		function _getAssociationHtml( associationType, association, level ) {
			if ( association && ( association[ level ].length > 0 ) ) {
				var pressType = "short";
				if ( level === 1 ) {
					pressType = "long";
				}
				return	'<span class="edisiogateway-association edisiogateway-association-' + associationType + '" title="' + associationType + ' associated with ' + pressType + ' press">'
					+		'<span class="edisio-' + pressType + '-press">'
					+			association[ level ].join( "," )
					+		'</span>'
					+	'</span>';
			}
			return "";
		}
		_indexChannels = {};
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.devices.length > 0 ) {
					var html =	'<table><tr><th>Type</th><th>Product Id</th><th>Device</th><th>Association</th><th>Action</th></tr>';
					$.each( devicesInfos.devices, function( i, device ) {
						var rowSpan = ( device.channels.length > 1 ? ' rowspan="' + device.channels.length + '"' : '' );
						html += '<tr>'
							+		'<td' + rowSpan + '><div>' + device.model + ' - ' + device.modelDesc + '</div><div class="description">' + device.modelFunction + '</div></td>'
							+		'<td' + rowSpan + '>' + device.productId + '</td>';
						var isFirstRow = true;
						// Sort the channels by id
						device.channels.sort( function( c1, c2 ) {
							return c1.id - c2.id;
						});
						$.each( device.channels, function( j, channel ) {
							var edisioId = device.productId + ',' + channel.id;
							_indexChannels[ edisioId ] = channel;
							channel.productId = device.productId;
							channel.isButton = device.isButton;
							channel.isReceiver = device.isReceiver;
							if ( !isFirstRow ) {
								html += '<tr>';
							}
							html +=	'<td>'
								+		'<div class="edisiogateway-device-channel">'
								+			channel.id + ". "
								+			channel.deviceName + ' (#' + channel.deviceId + ')'
								+			'<div class="edisiogateway-device-type">'
								+				_T( channel.deviceType )
								+				( api.getDeviceStateVariable( channel.deviceId, "urn:upnp-org:serviceId:EdisioDevice1", "PulseMode", { dynamic: false } ) === "1"  ? ' PULSE' : '' )
								+			'</div>'
								+		'</div>'
								+	'</td>'
								+	'<td>'
								+		_getAssociationHtml( "device", channel.association.devices, 0 )
								+		_getAssociationHtml( "device", channel.association.devices, 1 )
								+		_getAssociationHtml( "scene", channel.association.scenes, 0 )
								+		_getAssociationHtml( "scene", channel.association.scenes, 1 )
								+	'</td>'
								+	'<td align="center">'
								+		'<span class="edisiogateway-actions icon big icon-menu" data-edisio-id="' + edisioId + '"></span>'
								+	'</td>'
								+ '</tr>';
							isFirstRow = false;
						} );
					});
					html += '</table>';
					$("#edisiogateway-known-devices").html( html );
				} else {
					$("#edisiogateway-known-devices").html("There's no edisio device.");
				}
			} );
	}

	/**
	 * 
	 */
	function _showDeviceActions( position, isButton, isReceiver, channelId ) {
		var html = '<table>'
				+		'<tr>'
				+			'<td>'
				+				( isButton ?
								'<button type="button" class="edisiogateway-show-association">Associate</button>'
								: '')
				+				( isButton || ( isReceiver &&  ( channelId == 1 ) ) ?
								'<button type="button" class="edisiogateway-show-params">Params</button>'
								: '')
				+			'</td>';
		if ( isReceiver ) {
			html +=			'<td bgcolor="#FF0000">'
				+				'<button type="button" class="edisiogateway-teach">Teach in</button>'
				+				'<button type="button" class="edisiogateway-clear">Clear</button>'
				+			'</td>';
		}
		html +=			'</tr>'
			+		'</table>';
		var $actions = $( "#edisiogateway-device-actions" );
		$actions
			.html( html )
			.css( {
				"display": "block",
				"left": ( position.left - $actions.width() + 5 ),
				"top": ( position.top - $actions.height() / 2 )
			} );
	}

	/**
	 * Device associations
	 */
	function _showDeviceAssociation( edisioId, channel ) {
		var html = '<div class="edisiogateway-header">'
				+		'Association for ' + edisioId + ' - ' + channel.deviceName + ' (#' + channel.deviceId + ')'
				+	'</div>'
				+	'<div class="edisiogateway-toolbar">'
				+		'<button type="button" class="edisiogateway-help"><span class="icon icon-help"></span>Help</button>'
				+	'</div>'
				+	'<div class="edisiogateway-explanation edisiogateway-hidden">'
				+		_T( "ExplanationAssociation" )
				+	'</div>';

		// Get compatible devices
		var devices = [];
		$.each( api.getListOfDevices(), function( i, device ) {
			if ( device.id == channel.deviceId ) {
				return;
			}
			// Check if device is compatible
			var isCompatible = false;
			for ( var j = 0; j < device.states.length; j++ ) {
				if ( ( device.states[j].service === SWP_SID ) || ( device.states[j].service === SWD_SID ) ) {
					// Device can be switched or dimmed
					isCompatible = true;
					break;
				}
			}
			if ( !isCompatible ) {
				return;
			}
			// Check if device is an edisio device
			var isEdisio = false;
			for ( var j = 0; j < device.states.length; j++ ) {
				if ( device.states[j].service === EDISIODEVICE_SID ) {
					isEdisio = true;
					break;
				}
			}
			var room = ( device.room ? api.getRoomObject( device.room ) : null );
			if ( isEdisio ) {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": "(edisio) " + device.name,
					"type": 3,
					"isEdisio": isEdisio
				} );
			} else {
				devices.push( {
					"id": device.id,
					"roomName": ( room ? room.name : "_No room" ),
					"name": device.name,
					"type": 2,
					"isEdisio": isEdisio
				} );
			}
		} );
		// Get scenes
		$.each( jsonp.ud.scenes, function( i, scene ) {
			var room = ( scene.room ? api.getRoomObject( scene.room ) : null );
			devices.push( {
				"id": scene.id,
				"roomName": ( room ? room.name : "_No room" ),
				"name": "(Scene) " + scene.name,
				"type": 1
			} );
		} );

		// Sort devices/scenes by Room/Type/name
		devices.sort( function( d1, d2 ) {
			var r1 = d1.roomName.toLowerCase();
			var r2 = d2.roomName.toLowerCase();
			if (r1 < r2) return -1;
			if (r1 > r2) return 1;
			var n1 = d1.name.toLowerCase();
			var n2 = d2.name.toLowerCase();
			if (n1 < n2) return -1;
			if (n1 > n2) return 1;
			return 0;
		} );

		function _getCheckboxHtml( deviceId, association, level ) {
			var pressType = "short";
			if ( level === 1 ) {
				pressType = "long";
			}
			return	'<span class="edisio-' + pressType + '-press" title="' + pressType + ' press">'
				+		'<input type="checkbox"' + ( association && ( $.inArray( parseInt( deviceId, 10 ), association[level] ) > -1 ) ? ' checked="checked"' : '' ) + '>'
				+	'</span>';
		}

		var currentRoomName = "";
		$.each( devices, function( i, device ) {
			if ( device.roomName !== currentRoomName ) {
				currentRoomName = device.roomName;
				html += '<div class="edisiogateway-association-room">' +  device.roomName + '</div>';
			}
			if ( device.type === 1 ) {
				// Scene
				html += '<div class="edisiogateway-association edisiogateway-association-scene" data-scene-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, channel.association.scenes, 0 )
					+			_getCheckboxHtml( device.id, channel.association.scenes, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			} else if ( device.type === 3 ) {
				// Edisio : direct association (TODO)
				/*
				html += '<div class="edisiogateway-association edisiogateway-association-edisiodevice" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, channel.association.devices, 0 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
				*/
			} else {
				// Classic device (e.g. Z-wave)
				html += '<div class="edisiogateway-association edisiogateway-association-device" data-device-id="' + device.id + '">'
					+		'<label>'
					+			_getCheckboxHtml( device.id, channel.association.devices, 0 )
					+			_getCheckboxHtml( device.id, channel.association.devices, 1 )
					+			'&nbsp;' + device.name + ' (#' + device.id + ')'
					+		'</label>'
					+	'</div>';
			}
		} );

		html += '<div class="edisiogateway-toolbar">'
			+		'<button type="button" class="edisiogateway-cancel"><span class="icon icon-cancel"></span>Cancel</button>'
			+		'<button type="button" class="edisiogateway-associate"><span class="icon icon-ok"></span>Associate</button>'
			+	'</div>';

		$( "#edisiogateway-device-association" )
			.html( html )
			.css( {
				"display": "block"
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#edisiogateway-known-panel" ).offset().top - 150 );
	}
	function _hideDeviceAssociation() {
		$( "#edisiogateway-device-association" )
			.css( {
				"display": "none",
				"height": $( "#edisiogateway-known-panel" ).height()
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceAssociation() {
		function _getEncodedAssociation() {
			var associations = [];
			$("#edisiogateway-device-association .edisiogateway-association-device input:checked").each( function() {
				var deviceId = $( this ).parents( ".edisiogateway-association-device" ).data( "device-id" );
				if ( $( this ).parent().hasClass( "edisio-long-press" ) ) {
					associations.push( "+" + deviceId );
				} else {
					associations.push( deviceId );
				}
			});
			$("#edisiogateway-device-association .edisiogateway-association-scene input:checked").each( function() {
				var sceneId = $( this ).parents( ".edisiogateway-association-scene" ).data( "scene-id" );
				if ( $( this ).parent().hasClass( "edisio-long-press" ) ) {
					associations.push( "+*" + sceneId );
				} else {
					associations.push( "*" + sceneId );
				}
			});
			$("#edisiogateway-device-association .edisiogateway-association-edisiodevice input:checked").each( function() {
				var deviceId = $( this ).parents( ".edisiogateway-association-edisiodevice" ).data( "device-id" );
				associations.push( "%" + deviceId );
			});
			return associations.join( "," );
		}

		$.when( _performActionAssociate( _selectEdisioId, _getEncodedAssociation() ) )
			.done( function() {
				_drawDevicesList();
				_hideDeviceAssociation();
			});
	}

	/**
	 * Device parameters
	 */
	function _showDeviceParams( edisioId, channel ) {
		var html = '<div class="edisiogateway-header">'
				+		'Params for ' + edisioId + ' - ' + channel.deviceName + ' (#' + channel.deviceId + ')'
				+	'</div>'
				+	'<div class="edisiogateway-toolbar">'
				+		'<button type="button" class="edisiogateway-help"><span class="icon icon-help"></span>Help</button>'
				+	'</div>'
				+	'<div class="edisiogateway-explanation edisiogateway-hidden">'
				+		_T( "ExplanationParams" )
				+	'</div>';

		if ( channel.isButton ) {
			var isPulse = ( api.getDeviceStateVariable( channel.deviceId, "urn:upnp-org:serviceId:EdisioDevice1", "PulseMode", { dynamic: false } ) === "1" )
			html += '<div class="edisiogateway-param edisiogateway-param-pulse" data-device-id="' + channel.deviceId + '">'
				+		'<input type="checkbox"' + ( isPulse ? ' checked="checked"' : '' ) + '>'
				+		' Pulse'
				+	'</div>';
		}
		if ( channel.isReceiver ) {
			if ( channel.id != 1 ) {
				html += 'Edisio parameters can only been set on the channel 1';
			} else {
				html += 'TODO';
			}
		}

		html += '<div class="edisiogateway-toolbar">'
			+		'<button type="button" class="edisiogateway-cancel"><span class="icon icon-cancel"></span>Cancel</button>'
			+		'<button type="button" class="edisiogateway-set"><span class="icon icon-ok"></span>Set</button>'
			+	'</div>';

		$( "#edisiogateway-device-params" )
			.html( html )
			.css( {
				"display": "block",
				"height": $( "#edisiogateway-known-panel" ).height()
			} );

		_formerScrollTopPosition = $( window ).scrollTop();
		$( window ).scrollTop( $( "#edisiogateway-known-panel" ).offset().top - 150 );
	}
	function _hideDeviceParams() {
		$( "#edisiogateway-device-params" )
			.css( {
				"display": "none"
			} );
		if ( _formerScrollTopPosition > 0 ) {
			$( window ).scrollTop( _formerScrollTopPosition );
		}
	}
	function _setDeviceParams() {
		var deviceId = $( "#edisiogateway-device-params .edisiogateway-param-pulse" ).data( "device-id" );
		var pulseMode = ( $("#edisiogateway-device-params .edisiogateway-param-pulse input:checked").length > 0 ) ? "1" : "0";
		api.setDeviceStateVariable( deviceId, "urn:upnp-org:serviceId:EdisioDevice1", "PulseMode", pulseMode, { dynamic: false } );

		_drawDevicesList();
		_hideDeviceParams();
	}

	/**
	 * Show edisio devices
	 */
	function _showDevices( deviceId ) {
		try {
			_deviceId = deviceId;
			api.setCpanelContent(
					'<div id="edisiogateway-known-panel" class="edisiogateway-panel">'
				+		'<div class="edisiogateway-toolbar">'
				+			'<button type="button" class="edisiogateway-help"><span class="icon icon-help"></span>Help</button>'
				+			'<button type="button" class="edisiogateway-refresh"><span class="icon icon-refresh"></span>Refresh</button>'
				+		'</div>'
				+		'<div class="edisiogateway-explanation edisiogateway-hidden">'
				+			_T( "ExplanationKnownDevices" )
				+		'</div>'
				+		'<div id="edisiogateway-known-devices" class="edisiogateway-devices">'
				+			_T( "NoDevice" )
				+		'</div>'
				+		'<div id="edisiogateway-device-actions" style="display: none;"></div>'
				+		'<div id="edisiogateway-device-association" style="display: none;"></div>'
				+		'<div id="edisiogateway-device-params" style="display: none;"></div>'
				+	'</div>'
			);

			// Manage UI events
			$( "#edisiogateway-known-panel" )
				.delegate( ".edisiogateway-help", "click", function() {
					$( this ).parent().next( ".edisiogateway-explanation" ).toggleClass( "edisiogateway-hidden" );
				} )
				.delegate( ".edisiogateway-refresh", "click", function() {
					$.when( _performActionRefresh() )
						.done( function() {
							_drawDevicesList();
						});
				} )
				.click( function() {
					$( "#edisiogateway-device-actions" ).css( "display", "none" );
				} )
				.delegate( ".edisiogateway-actions", "click", function( e ) {
					var position = $( this ).position();
					position.left = position.left + $( this ).outerWidth();
					_selectEdisioId = $( this ).data( "edisio-id" );
					var selectedChannel = _indexChannels[ _selectEdisioId ];
					_showDeviceActions( position, selectedChannel.isButton, selectedChannel.isReceiver, selectedChannel.id );
					e.stopPropagation();
				} )
				.delegate( ".edisiogateway-show-association", "click", function() {
					_showDeviceAssociation( _selectEdisioId, _indexChannels[ _selectEdisioId ] );
				} )
				.delegate( ".edisiogateway-show-params", "click", function() {
					_showDeviceParams( _selectEdisioId, _indexChannels[ _selectEdisioId ] );
				} )
				.delegate( ".edisiogateway-cancel", "click", function() {
					_hideDeviceAssociation();
					_hideDeviceParams();
				} )
				// Association event
				.delegate( ".edisiogateway-associate", "click", _setDeviceAssociation )
				// Parameters event
				.delegate( ".edisiogateway-set", "click", _setDeviceParams )
				// Teach (receiver) event
				.delegate( ".edisiogateway-teach", "click", function() {
					api.showCustomPopup( _T( "ConfirmationTeachInReceiver" ), {
							category: "confirm",
							onSuccess: function() {
								_performActionTeachIn( _selectEdisioId );
								return true;
							}
						}
					);
				} )
				// Clear (receiver) event
				.delegate( ".edisiogateway-clear", "click", function() {
					api.showCustomPopup( _T( "ConfirmationClearingReceiver" ), {
							category: "confirm",
							onSuccess: function() {
								_performActionClear( _selectEdisioId );
								return true;
							}
						}
					);
				} );

			// Show devices infos
			_drawDevicesList();

		} catch (err) {
			Utils.logError('Error in EdisioGateway.showDevices(): ' + err);
		}
	}

	// *************************************************************************************************
	// Discovered edisio devices
	// *************************************************************************************************

	/**
	 * Draw and manage discovered edisio device list
	 */
	function _drawDiscoveredDevicesList() {
		if ( $( "#edisiogateway-discovered-devices" ).length === 0 ) {
			return;
		}
		$.when( _getDevicesInfosAsync() )
			.done( function( devicesInfos ) {
				if ( devicesInfos.discoveredDevices.length > 0 ) {
					// Sort the discovered edisio devices by last update
					devicesInfos.discoveredDevices.sort( function( d1, d2 ) {
						return d1.lastUpdate - d2.lastUpdate;
					});
					var html =	'<table><tr><th>Type</th><th>Product Id</th><th>Last update</th><th>Channels</th></tr>';
					$.each( devicesInfos.discoveredDevices, function( i, discoveredDevice ) {
						html += '<tr>'
							+		'<td><div>' + discoveredDevice.model + ' - ' + discoveredDevice.modelDesc + '</div><div class="description">' + discoveredDevice.modelFunction + '</div></td>'
							+		'<td>' + discoveredDevice.productId + '</td>'
							+		'<td>' + _convertTimestampToLocaleString( discoveredDevice.lastUpdate ) + '</td>'
							+		'<td>';
						$.each( discoveredDevice.channelIds, function( j, channelId ) {
							var channelTypes = discoveredDevice.channelTypes.slice();
							if ( channelId % 2 === 0 ) {
								// Shutter take 2 channels and can just be selected on odd channel
								var pos = $.inArray( "WINDOW_COVERING", channelTypes);
								if ( pos > -1 ) {
									channelTypes.splice( pos, 1 );
								}
							}
							html +=		'<div class="edisiogateway-device-channel"'
									+			' data-product-id="' + discoveredDevice.productId + '"'
									+			' data-channel-id="' + channelId + '"'
									+	'>';
							if ( channelTypes.length > 1 ) {
								html +=		'<label>'
									+			'<input type="checkbox">'
									+			'&nbsp;' + channelId + '.'
									+		'</label>'
									+		'&nbsp;'
									+		'<select>';
								$.each( channelTypes, function( k, channelType ) {
									html +=		'<option value="' + channelType + '">' + channelType + '</option>';
								} );
								html +=		'</select>';
							} else {
								html +=		'<label>'
									+			'<input type="checkbox">'
									+			'&nbsp;' + channelId + '.'
									+			'&nbsp;' + channelTypes[0]
									+		'</label>';
							}
							html +=		'</div>';
						} );
						html +=		'</td>'
							+	'</tr>';
					});
					html += '</table>';
					$("#edisiogateway-discovered-devices").html( html );
				} else {
					$("#edisiogateway-discovered-devices").html( "There's no discovered edisio device." );
				}
			} );
	}

	/**
	 * Show edisio discovered devices
	 */
	function _showDiscoveredDevices( deviceId ) {
		try {
			_deviceId = deviceId;
			api.setCpanelContent(
					'<div id="edisiogateway-discovered-panel" class="edisiogateway-panel">'
				+		'<div class="edisiogateway-toolbar">'
				+			'<button type="button" class="edisiogateway-help"><span class="icon icon-help"></span>Help</button>'
				//+			'<button type="button" class="edisiogateway-ignore"><span class="icon icon-ignore"></span>Ignore</button>'
				+			'<button type="button" class="edisiogateway-learn"><span class="icon icon-ok"></span>Learn</button>'
				+		'</div>'
				+		'<div class="edisiogateway-explanation edisiogateway-hidden">'
				+			_T( "ExplanationDiscoveredDevices" )
				+		'</div>'
				+		'<div id="edisiogateway-discovered-devices" class="edisiogateway-devices">'
				+			"There's no edisio discovered device."
				+		'</div>'
				+	'</div>'
			);

			function _getSelectedEdisioIds() {
				var items = [];
				$("#edisiogateway-discovered-devices input:checked:visible").each( function() {
					var $channel = $( this ).parents( ".edisiogateway-device-channel" );
					var productId = $channel.data( "product-id" );
					var channelId = $channel.data( "channel-id" );
					var $select = $( this ).closest( ".edisiogateway-device-channel" ).find( "select" );
					if ( $select.length > 0 ) {
						items.push( productId + "," + channelId + "," + $select.val() );
					} else {
						items.push( productId + "," + channelId );
					}
				});
				return items;
			}

			// Manage UI events
			$( "#edisiogateway-discovered-panel" )
				.delegate( ".edisiogateway-help", "click" , function() {
					$( ".edisiogateway-explanation" ).toggleClass( "edisiogateway-hidden" );
				} )
				.delegate( ".edisiogateway-learn", "click", function( e ) {
					var edisioIds = _getSelectedEdisioIds();
					if ( edisioIds.length === 0 ) {
						alert( "You have to select the channels of the products you want to learn." );
					} else {
						api.showCustomPopup( _T( "Confirmation for learning the edisio devices" ) + " " + edisioIds, {
								category: "confirm",
								onSuccess: function() {
									$.when( _performActionCreateDevices( edisioIds ) )
										.done( function() {
											$( "#edisiogateway-discovered-devices" ).html( _T( "WaitReload" ) );
										} );
									return true;
								}
							}
						);
					}
				} )
				.delegate( ".edisiogateway-ignore", "click", function( e ) {
					alert( "TODO" );
				} )
				.delegate( "select", "change", function( e ) {
					var value = $( this ).val();
					var $channel = $( this ).parents( ".edisiogateway-device-channel" );
					var productId = $channel.data( "product-id" );
					var channelId = parseInt( $channel.data( "channel-id" ) , 10 ) + 1;
					$( "#edisiogateway-discovered-panel .edisiogateway-device-channel[data-product-id=\"" + productId + "\"][data-channel-id=\"" + channelId + "\"]" )
						.css( "visibility", ( value === "WINDOW_COVERING" ? "hidden" : "visible" ) );
				} );
				;

			// Show discovered devices infos
			_drawDiscoveredDevicesList();

		} catch (err) {
			Utils.logError('Error in EdisioGateway.showDevices(): ' + err);
		}
	}

	// *************************************************************************************************
	// Actions
	// *************************************************************************************************

	/**
	 * 
	 */
	function _performActionRefresh() {
		Utils.logDebug( "[EdisioGateway.performActionRefresh] Refresh the list of edisio devices" );
		return Utils.performActionOnDevice(
			_deviceId, EDISIOGATEWAY_SID, "Refresh", {
				output_format: "json"
			}
		)
	}

	/**
	 * 
	 */
	function _performActionCreateDevices( edisioIds ) {
		Utils.logDebug( "[EdisioGateway.performActionCreateDevices] Create edisio product/channel '" + edisioIds + "'" );
		return Utils.performActionOnDevice(
			_deviceId, EDISIOGATEWAY_SID, "CreateDevices", {
				output_format: "json",
				edisioIds: edisioIds.join( "|" )
			}
		);
	}

	/**
	 * 
	 */
	function _performActionTeachIn( edisioId ) {
		Utils.logDebug( "[EdisioGateway.performActionTeachIn] Teach in edisio product/channel '" + edisioId + "'" );
		return Utils.performActionOnDevice(
			_deviceId, EDISIOGATEWAY_SID, "TeachIn", {
				output_format: "json",
				edisioId: edisioId
			}
		);
	}

	/**
	 * 
	 */
	function _performActionClear( edisioId ) {
		Utils.logDebug( "[EdisioGateway.performActionClear] Clear edisio product '" + edisioId + "'" );
		return Utils.performActionOnDevice(
			_deviceId, EDISIOGATEWAY_SID, "Clear", {
				output_format: "json",
				edisioId: edisioId
			}
		);
	}

	/**
	 *
	 */
	function _performActionAssociate( edisioId, association, callback ) {
		Utils.logDebug( "[EdisioGateway.performActionAssociate] Associate edisio product/channel '" + edisioId + "' with " + association );
		return Utils.performActionOnDevice(
			_deviceId, EDISIOGATEWAY_SID, "Associate", {
				output_format: "json",
				edisioId: edisioId,
				association: encodeURIComponent(association)
			}
		);
	}

	// *************************************************************************************************
	// Errors
	// *************************************************************************************************

	/**
	 * Get errors
	 */
	function _getErrorsAsync() {
		var d = $.Deferred();
		api.showLoadingOverlay();
		$.ajax( {
			url: Utils.getDataRequestURL() + "id=lr_EdisioGateway&command=getErrors&output_format=json#",
			dataType: "json"
		} )
		.done( function( errors ) {
			api.hideLoadingOverlay();
			if ( $.isArray( errors ) ) {
				d.resolve( errors );
			} else {
				Utils.logError( "No errors" );
				d.reject();
			}
		} )
		.fail( function( jqxhr, textStatus, errorThrown ) {
			api.hideLoadingOverlay();
			Utils.logError( "Get errors error : " + errorThrown );
			d.reject();
		} );
		return d.promise();
	}

	/**
	 * Draw errors list
	 */
	function _drawErrorsList() {
		if ( $( "#edisiogateway-errors" ).length === 0 ) {
			return;
		}
		$.when( _getErrorsAsync() )
			.done( function( errors ) {
				if ( errors.length > 0 ) {
					var html = '<table><tr><th>Date</th><th>Error</th></tr>';
					$.each( errors, function( i, error ) {
						html += '<tr>'
							+		'<td>' + _convertTimestampToLocaleString( error[0] ) + '</td>'
							+		'<td>' + error[1] + '</td>'
							+	'</tr>';
					} );
					html += '</table>';
					$("#edisiogateway-errors").html( html );
				} else {
					$("#edisiogateway-errors").html( _T( "NoError" ) );
				}
			} );
	}

	/**
	 * Show errors tab
	 */
	function _showErrors( deviceId ) {
		_deviceId = deviceId;
		try {
			api.setCpanelContent(
					'<div id="edisiogateway-errors-panel" class="xee-panel">'
				/*+		'<div class="edisiogateway-toolbar">'
				+			'<button type="button" class="edisiogateway-help"><span class="icon icon-help"></span>Help</button>'
				+		'</div>'
				+		'<div class="edisiogateway-explanation edisiogateway-hidden">'
				+			_T( "Explanation for errors" )
				+		'</div>'*/
				+		'<div id="edisiogateway-errors">'
				+		'</div>'
				+	'</div>'
			);
			// Manage UI events
			/*$( "#edisiogateway-errors-panel" )
				.on( "click", ".edisiogateway-help" , function() {
					$( ".edisiogateway-explanation" ).toggleClass( "edisiogateway-hidden" );
				} );*/
			// Display the errors
			_drawErrorsList();
		} catch ( err ) {
			Utils.logError( "Error in EdisioGateway.showErrors(): " + err );
		}
	}

	// *************************************************************************************************
	// Donate
	// *************************************************************************************************

	function _showDonate( deviceId ) {
		var donateHtml = '\
<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank">\
<input type="hidden" name="cmd" value="_s-xclick">\
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----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-----END PKCS7-----">\
<input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">\
<img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1">\
</form>';

		api.setCpanelContent(
				'<div id="edisiogateway-donate-panel" class="edisiogateway-panel">'
			+		'<div id="edisiogateway-donate">'
			+			'<span>This plugin is free but if you install and find it useful then a donation to support further development is greatly appreciated</span>'
			+			donateHtml
			+		'</div>'
			+	'</div>'
		);
	}

	// *************************************************************************************************
	// Main
	// *************************************************************************************************

	myModule = {
		uuid: _uuid,
		onDeviceStatusChanged: _onDeviceStatusChanged,
		showDevices: _showDevices,
		showDiscoveredDevices: _showDiscoveredDevices,
		showErrors: _showErrors,
		showDonate: _showDonate,

		ALTUI_drawDevice: function( device ) {
			var status = parseInt( MultiBox.getStatus( device, "urn:upnp-org:serviceId:SwitchPower1", "Status" ), 10 );
			var version = MultiBox.getStatus( device, "urn:upnp-org:serviceId:EdisioGateway1", "PluginVersion" );
			return '<div class="panel-content">'
				+		ALTUI_PluginDisplays.createOnOffButton( status, "altui-edisiogateway-" + device.altuiid, _T( "OFF,ON" ), "pull-right" )
				+		'<div class="btn-group" role="group" aria-label="...">'
				+			'v' + version
				+		'</div>'
				+	'</div>'
				+	'<script type="text/javascript">'
				+		'$("div#altui-edisiogateway-{0}").on("click touchend", function() { ALTUI_PluginDisplays.toggleOnOffButton("{0}", "div#altui-edisiogateway-{0}"); } );'.format( device.altuiid )
				+	'</script>';
		}
	};

	// Register
	if ( !_registerIsDone ) {
		api.registerEventHandler( "on_ui_deviceStatusChanged", myModule, "onDeviceStatusChanged" );
		_registerIsDone = true;
	}

	// UI5 compatibility
	if ( api.version === "UI5" ) {
		window[ "EdisioGateway.showDevices" ] = _showDevices;
		window[ "EdisioGateway.showDiscoveredDevices" ] = _showDiscoveredDevices;
		window[ "EdisioGateway.showErrors" ] = _showErrors;
		window[ "EdisioGateway.showDonate" ] = _showDonate;
	}

	return myModule;

})( api, jQuery );
