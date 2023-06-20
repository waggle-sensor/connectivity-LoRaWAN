# Waggle LoRaWAN Usage Instructions

The [Waggle Edge Stack (WES)](https://github.com/waggle-sensor/waggle-edge-stack) has support for LoRaWAN devices using the [chirpstack.io](https://www.chirpstack.io/docs/index.html) stack.

**Table of Contents**
- [Setting up RAK Discover Kit 2 to be discoverable by WES](#setting-up-rak-discover-kit-2-to-be-discoverable-by-wes)
- [Enabling WES access to the RAK concentrator](#enabling-wes-access-to-the-rak-concentrator)
- [Configuring the WES LoraWAN](#configuring-the-wes-lorawan)
  - [1. Identify the `wes-chirpstack-server` service address](#1-identify-the-wes-chirpstack-server-service-address)
  - [2. `ssh` proxy connect to the Waggle node](#2-ssh-proxy-connect-to-the-waggle-node)
  - [3. Open the Chirpstack Web UI in a browser](#3-open-the-chirpstack-web-ui-in-a-browser)
  - [4. Connect to the `wes-gateway`](#4-connect-to-the-wes-gateway)
  - [5. Add the Application](#5-add-the-application)
  - [6. Creating Device Profiles from the built-in templates](#6-creating-device-profiles-from-the-built-in-templates)
  - [7. Add Devices to the `wes-application`](#7-add-devices-to-the-wes-application)
    - [_OTAA Device Activation_](#otaa-device-activation)
    - [_ABP Device Activation_](#abp-device-activation)
- [Adding Custom Device Profiles](#adding-custom-device-profiles)
  - [Add the 'ABP' device profile](#add-the-abp-device-profile)
  - [Add the 'OTAA' device profile](#add-the-otaa-device-profile)
- [Accessing LoRa End Device via Minicom](#accessing-lora-end-device-via-minicom)

## Setting up RAK Discover Kit 2 to be discoverable by WES

To allow the RAK Discover Kit 2 to be detected by WES, you need to ensure that the device can establish communication with the node. Here are the steps to follow in order to achieve this:

1) Refer to the [Quick Start Guide](https://docs.rakwireless.com/Product-Categories/WisLink/RAK2287/Quickstart), to ssh into the gateway
- Default username: `pi`
- Default password: `raspberry`
2) Assuming you have successfully logged into your gateway using SSH. Enter the following command in the command line: `sudo gateway-config`
3) Set eth0 ip address to the same network as the node and set eth0 gateway ip to the NX's ip address, refer to [Connect through Ethernet](https://docs.rakwireless.com/Product-Categories/WisLink/RAK2287/Quickstart/#connect-through-ethernet) on how to do so.
- For example if the node's ip address is 10.31.81.50, then change the eth0 ip address to 10.31.81.51
- The NX's ip address always ends with 1, so based on the example above the NX's ip address will be 10.31.81.1
4) Add the node's NX IP address as a DNS server to the gateway, to do so add the IP address to RPI's `/etc/resolv.conf`
5) Enable Linux's memory controller, to do so change `/boot/cmdline.txt` from:
```
console=tty1 root=PARTUUID=24e4d811-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait modules-load=dwc2,g_ether
```
to:
```
console=tty1 root=PARTUUID=24e4d811-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait modules-load=dwc2,g_ether cgroup_memory=1 cgroup_enable=memory
```
6) Join the K3s cluster, to do so run this in the command line
```
MACLower=$(sed s/://g /sys/class/net/eth0/address)
MAC=${MACLower^^}
MACFULL=$(printf "0000%5s\n" "$MAC")
hostname=$(cat /etc/hostname)

export K3S_URL=https://10.31.81.1:6443
export K3S_TOKEN=4tX0DUZ0uQknRtVUAKjt
export K3S_NODE_NAME=$MACFULL.$hostname

curl -sfL https://get.k3s.io | sh
```
7) Configure the local Docker registry access, to do so run this in the command line
```
echo "Configure local Docker registery access" | xargs -L 1 echo `date +'[%Y-%m-%d %H:%M:%S]'` >> /etc/rc.local.logs
mkdir -p /etc/docker/certs.d/10.31.81.1\:5000/
cp /etc/waggle/docker/certs/domain.crt /etc/docker/certs.d/10.31.81.1\:5000/
mkdir -p /usr/local/share/ca-certificates
cp /etc/waggle/docker/certs/domain.crt /usr/local/share/ca-certificates/docker.crt
update-ca-certificates
```
8) After doing the above steps, the gateway should now be discoverable by WES. It should be named `rak-gateway`. If the gateway is not appearing restart the rpi.
```
root@ws-nxcore-000048B02D0766BE:~# sudo kubectl get node
NAME                           STATUS     ROLES                  AGE   VERSION
000048b02d0766cd.ws-nxagent    NotReady   <none>                 24d   v1.25.4+k3s1
0000dca632a306b4.ws-rpi        NotReady   <none>                 24d   v1.25.4+k3s1
000048b02d0766be.ws-nxcore     Ready      control-plane,master   24d   v1.25.4+k3s1
0000e45f01384120.rak-gateway   Ready      <none>                 11s   v1.25.7+k3s1 << look for something like this
```

## Enabling WES access to the RAK concentrator

In order for the RAK concentrator (Model: RAK7248, Module: [RAK2287](https://store.rakwireless.com/products/rak2287-lpwan-gateway-concentrator-module?variant=41826859385030)) to be accessed by the WES Chirpstack the [Waggle Node's](https://docs.waggle-edge.ai/docs/about/architecture#waggle-nodes) RPi needs to be properly `labeled` within Kubernetes.

> Note: this will automatically be done in a later update to https://github.com/waggle-sensor/wes-device-labeler but must be done manually for now.

To manually apply the `label` perform the following steps:

> **The below steps are temporary because of how the https://github.com/waggle-sensor/wes-device-labeler works.  The device-labeler removes any labels that aren't in the cloud manifest and also verified via a hardware availability test.** So the below steps can be used to get the gateway-bridge to run, but after a short time the gateway-bridge will be terminated by K3S due to the missing node label.

- login to the node
  ```bash
  $ ssh waggle-dev-node-W030
  ```

- identify the ID of the RPi
  ```bash
  $ sudo kubectl get node
  NAME                          STATUS   ROLES                  AGE    VERSION
  0000e45f012e8689.ws-rpi       Ready    <none>                 47d    v1.20.2+k3s1
  000048b02d0766cd.ws-nxagent   Ready    <none>                 49d    v1.20.2+k3s1
  000048b02d0766be.ws-nxcore    Ready    control-plane,master   196d   v1.20.2+k3s1
  ```

- apply the `resource.lorawan` label to the RPi
  ```bash
  $ sudo kubectl label node 0000e45f012e8689.ws-rpi resource.lorawan=true
  node/0000e45f012e8689.ws-rpi labeled
  ```

- verify the `wes-chirpstack-gateway-bridge` pod is running
  ```bash
  $ sudo kubectl get pod | grep wes-chirpstack-gateway-bridge
  wes-chirpstack-gateway-bridge-fbbdd4f4c-ksqjr    2/2     Running        0          5m27s
  ```

> Note: to remove the label you can execute the following example command: `sudo kubectl label node 0000e45f012e8689.ws-rpi resource.lorawan-`

## Configuring the WES LoraWAN

Access to the LoRaWAN device(s) data is configured using the [chirpstack.io](https://www.chirpstack.io/docs/index.html) software stack that is part of the default [Waggle Edge Stack (WES)](https://github.com/waggle-sensor/waggle-edge-stack) deployment (see [wes-chirpstack](https://github.com/waggle-sensor/waggle-edge-stack/tree/main/kubernetes/wes-chirpstack)). The configuration is done by accessing the [chirpstack.io application server](https://www.chirpstack.io/docs/chirpstack/configuration.html) Web UI on the target [Waggle Node](https://docs.waggle-edge.ai/docs/about/architecture#waggle-nodes).

The following documentation sources may be helpful in configuring the Chirpstack software stack and connecting LoRaWAN devices:
- Chirpstack Documentation: https://www.chirpstack.io/docs/index.html
- Initial investigation: https://github.com/waggle-sensor/summer2022/blob/main/Tsai/Documentation.md

### 1. Identify the `wes-chirpstack-server` service address

First, connect to the desired node (ex. `W030`) and identify the IP address of the `wes-chirpstack-server`

```bash
$ ssh waggle-dev-node-W030 "sudo kubectl get svc | grep wes-chirpstack-server | xargs | cut -d' ' -f3"
Welcome to our node SSH gateway, Joe Swantek!

We are connecting you to node W030 (000048B02D0766BE)...
10.43.12.212
```

### 2. `ssh` proxy connect to the Waggle node

Use the above identified IP address (ex. `10.43.12.212`) establish a proxy connection to the `wes-chirpstack-server` web UI

```bash
ssh -L 8080:10.43.12.212:8080 waggle-dev-node-w030
```

### 3. Open the Chirpstack Web UI in a browser

Enter the `wes-chirpstack-server` Web UI address http://localhost:8080/ into a browser

You will be presented with a login UI

![](_images/01_login.png)

Login with the `admin` / `admin` credentials. You will be presented with an empty Chirpstack dashboard

### 4. Connect to the `wes-gateway`

Reference:
- Chirpstack gateway docs: https://www.chirpstack.io/docs/chirpstack/use/gateways.html

Click on 'Gateways' under the 'Tenant' section on the left. Select the 'Add Gateway' button (on the upper right). Enter the following:
- `wes-gateway` for the 'Name'
- `D2CE19FFFEC9D449` for the 'Gateway ID (EUI64)'

![](_images/02_add_gateway.png)

Scroll to the bottom and click the 'Submit' button. 

Clicking on 'Gateways' under the 'Tenant' section on the left should show the newly added gateway with a recent 'Last seen' time.

![](_images/03_gateway_confirm.png)

> Note: it may take a few moments for the 'Last seen' to be populated and a URL re-fresh may be necessary. If the 'Last seen' is not populated then there is an issue that needs to be debugged.

Clicking on the 'Gateway ID' will take you to the gateway details page where you can view the most recent LoRaWAN data via the 'LoRaWAN frames' tab.

![](_images/04_gateway_frames.png)

From here you can click on any frames 'ConfirmedDataUp' link to see the details of the frame.

![](_images/05_frame_details.png)

### 5. Add the Application

LoRaWAN devices are associated with a Chirpstack "application" and therefore an "application" needs to be created.

Reference:
- Chirpstack application docs: https://www.chirpstack.io/docs/chirpstack/use/applications.html

Click on 'Applications' under the 'Tenant' section on the left. Select the 'Add application' button (on the upper right). Enter the following:
- `wes-application` for the 'Name'

![](_images/16_add_application.png)

Click the 'Submit' button.

![](_images/17_add_application_done.png)

### 6. Creating Device Profiles from the built-in templates

The Chirpstack server comes pre-loaded with hundreds of "Device-profile templates" from [The Things Network LoRaWAN devices github repository](https://github.com/TheThingsNetwork/lorawan-devices). In this step we will create "Device profiles" from these templates in order to properly configure the devices for connection to an "application" (below).

Devices are associated and authenticated to a Chirpstack "application".  There are two methods of authentication:
1. Over the Air Activation (OTAA)
2. Activation by Personalization (ABP)

|                 |                                                           ABP                                                            |                                                                OTAA                                                                |
| :-------------: | :----------------------------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------------------------------------: |
| **Description** | Uses Device Address (DevAddr), Network Session Key (NWK SKEY), and Application Session Key (APP SKEY) to join the server | Uses Application Key (APP KEY) for request joining the server. Once joined, The NWK SKEY, APP SKEY, and DevAddr will be generated. |
|    **Pros**     |                                          Can rejoin network after device reset                                           |                         The session keys don't have to be hardcoded; only the application key has to match                         |
|    **Cons**     |                             The DevAddr, NWKSKEY, APPSKEY have to be hardcoded in the device                             |                       To rejoin network after device reset, you have to manually match up the device address                       |

Reference:
- Chirpstack device-profile templates docs: https://www.chirpstack.io/docs/chirpstack/use/device-profile-templates.html
- Device activation technologies (ex. OTAA): https://www.chirpstack.io/docs/chirpstack/features/device-activation.html

The following instructions demonstrate adding two example device profiles:
- [MKR WAN 1310](https://store.arduino.cc/products/arduino-mkr-wan-1310)
- [LoRa E5-mini](https://www.seeedstudio.com/LoRa-E5-mini-STM32WLE5JC-p-4869.html)

Before we can add the devices to the `wes-application` we need to create "Device profiles" for the devices based on the "Device-profile templates".

Click on 'Device profiles' under the 'Tenant' section on the left. Select the 'Add device profile' button (on the upper right). Select the 'Select device-profile template'. Search for the device by clicking on the drop-down box.

For example, for the "MKR WAN 1310" you would select the following:
- Arduino SA -> Adruino MKR WAN 1310 -> FW version: <version> -> US915

![](_images/18_pick_device_template_01.png)

For example, for the "LoRa E5-mini" you would select the following:
- Seeed Technology Co., Ltd -> Wio-E5 Dev Kit, for Long Range Application -> FW version: <version> -> US915

![](_images/19_pick_device_template_02.png)

> Note: if you don't know the specifics of your device you can search for template definition within [The Things Network LoRaWAN devices github repository](https://github.com/TheThingsNetwork/lorawan-devices).

> Note: if you don't want to use a built in template, you can create custom "Device profiles" via the instructions below.

After selecting "OK", the "Device profile" will be loaded with all the template defaults.

![](_images/20_device_profile.png)

Click the "Submit" button after making any modifications.

After adding the "Device profiles" you will see a summary of all the created "Device profiles".

![](_images/21_device_profile_summary.png)

### 7. Add Devices to the `wes-application`

With the "Device profiles" created for the devices, the devices can now be added to the `wes-application`. 

Reference:
- Chirpstack devices docs: https://www.chirpstack.io/docs/chirpstack/use/devices.html
- Example MKRWAN setup: https://github.com/waggle-sensor/summer2022/blob/main/Tsai/Documentation.md#setting-up-the-mkrwan

From within the `wes-application` created above, click the 'Add device' button.

![](_images/22_app_add_device_button.png)

#### _OTAA Device Activation_

On the 'Add device' screen enter the following:
- a unique name (ex. `MKRWAN1310 Device 1`) for the 'Name'
- the device's EUI (ex. `123456789abcdeff`) for the 'Device EUI (EUI64)'. You may need to identify the device's EUI via a serial connection to the device see [Accessing LoRa End Device via Minicom](#accessing-lora-end-device-via-minicom).
- select the appropriate 'Device profile' (ex. `Adruino MKR WAN 1310`)

![](_images/23_app_add_device_otaa_details.png)

Click the "Submit" button.

Now you will be presented with a screen for the activation of the device.

For OTAA devices you will be asked for the 'Application key'.  You can randomly generate one or type in pre-defined key here.

![](_images/24_activation_otaa.png)

Click the "Submit" button.

You will then be presented with a dashboard for the device where you can check the 'OTAA keys', see 'Activation' status and browse the 'LoRaWAN frames'.

![](_images/25_dashboard_otaa.png)

To connect the LoRa End device one must change the mode to OTAA, configure the device with the 'Application key', and join the network. Refer to your device's manual on how to do so.

If you are using a Lora E5 Mini, this can be done using the at command `at+mode=lwotaa` to change the mode to OTAA. Then `at+key=appskey, {16 bytes length key}`. {16 bytes length key} being the application key to configure the application key. `at+join` to join the network. All these at commands can be sent using minicom, refer to [Accessing LoRa End Device via Minicom](#accessing-lora-end-device-via-minicom). You might also need to change the channel of the device to the channels supported in the region. In the US, this can be done using the command `at+ch=NUM,8-15`.

Once that is configured, the device should join the network and send an event to chirpstack viewable in the `Events` tab.

#### _ABP Device Activation_

If the device does not support OTAA activation, then ABP activation can be done.

Like the above OTAA configuration you will enter the following:
- a unique name (ex. `Test Device 1`) for the 'Name'
- the device's EUI (ex. `ffedcba987654321`) for the 'Device EUI (EUI64)'. You may need to identify the device's EUI via a serial connection to the device.
- select the appropriate 'Device profile' (ex. `testABP`)

![](_images/26_app_add_device_abp_details.png)

Click the 'Submit' button

You will then be presented with a dashboard for the device with the 'OTAA keys' disabled. Navigate to the 'Activation' tab to input the 'Device address', 'Network session key' and 'Application session key'.

![](_images/27_activation_abp.png)

Click '(Re)activate device`

To connect the LoRa End device one must change the mode to ABP, configure the device with the 'Device Address', 'Network Session Key', and 'Application Session Key'. Finally, after all three are configured the device must join the network. Refer to your device's manual on how to do so.

## Adding Custom Device Profiles

If the built in device profile templates are not sufficient then default "ADP" and "OTAA" device profiles can be configured.

References
- Initial investigation using an older Web UI: https://github.com/waggle-sensor/summer2022/blob/main/Tsai/Documentation.md#setup-device-profiles

### Add the 'ABP' device profile

In order for a LoRaWAN device to connect to an "application" (see below) it will need to authenticate using a device profile.

Click on 'Device profiles' under the 'Tenant' section on the left. Select the 'Add device profile' button (on the upper right). Enter the following:
- `ABP` for the 'Name'
- `US915` for the 'Region'
- `LoRaWAN 1.0.2` for the 'MAC version'
- `B` for the 'Regional parameters revision'
- `Default ADR algorithm (LoRa only)` for 'ADR algorithm'
- `30000` for 'Expected uplink interval (secs)'

> Note: the value for 'Expected uplink interval' may change based on the deployment configuration.

![](_images/06_abp_profile_main.png)

Select the 'Join (OTAA / ABP)' tab and disable the 'Device supports OTAA'

![](_images/07_abp_profile_join.png)

Select the 'Class-B' tab and enable the 'Device supports Class-B' 

![](_images/08_abp_profile_classb.png)

Select the 'Class-C' tab and enable the 'Device supports Class-C'

![](_images/09_abp_profile_classc.png)

> Note: it is possible to select the 'Payload codec' to have the Application Server decode the data.

Click the 'Submit' button.

![](_images/10_adp_profile_done.png)

### Add the 'OTAA' device profile

Just like was done for the above 'ABP' profile we need to add an 'OTAA' device profile to enable proper device connections.

Click on 'Device profiles' under the 'Tenant' section on the left. Select the 'Add device profile' button (on the upper right). Enter the following:
- `OTAA` for the 'Name'
- `US915` for the 'Region'
- `LoRaWAN 1.0.2` for the 'MAC version'
- `B` for the 'Regional parameters revision'
- `Default ADR algorithm (LoRa only)` for 'ADR algorithm'
- `80000` for 'Expected uplink interval (secs)'

> Note: the value for 'Expected uplink interval' may change based on the deployment configuration.

![](_images/11_otaa_profile_main.png)

Select the 'Join (OTAA / ABP)' tab and enable the 'Device supports OTAA'

![](_images/12_otaa_profile_join.png)

Select the 'Class-B' tab and disable the 'Device supports Class-B' 

![](_images/13_otaa_profile_classb.png)

Select the 'Class-C' tab and disable the 'Device supports Class-C'

![](_images/14_otaa_profile_classc.png)

> Note: it is possible to select the 'Payload codec' to have the Application Server decode the data.

Click the 'Submit' button.

![](_images/15_otaa_profile_done.png)

## Accessing LoRa End Device via Minicom

1) To connect to your LoRa End Device, you have to first connect your LoRa End Device to your personal device via a cable.

1) Launch minicom with the appropriate rights, `sudo minicom -s`

1) Go to Serial Port Setup. Configure the serial device on which is the cable (ex; /dev/ttyUSB0). Set the baud rate to the one specified in the device's manual (9600 for Lora E5 Mini).

1) Disable hardware and software flow controls. After that select Exit to close the configuration screen

1) Press `Ctrl-A` and then `E` to enable echo. Finally we are ready type commands

1) Type `at`, if you receive `+AT: OK` then you configured the connection correctly.

1) To Save the configurations use `configure minicom/save setup as...` accessed using `Ctrl-A` and then `Z`. Once this is saved you can access your saved environment with the command `sudo minicom {name}`, {name} being the name you saved it as.

1) When you send commands follow them with `Ctrl-J` to send in LF.

>NOTE: If you are receiving an input timeout issue or the command is sent to quick disabling you to type, try changing the timeout setting on the device. On the Lora E5 Mini, the at command `AT+UART=TIMEOUT, 0` disables the timeout feature.


## Learn More & Supporting Documentation

- [LoRa-E5 AT Command Specification](https://files.seeedstudio.com/products/317990687/res/LoRa-E5%20AT%20Command%20Specification_V1.0%20.pdf)
- [RAK2287 Quick Start Guide](https://docs.rakwireless.com/Product-Categories/WisLink/RAK2287/Quickstart/)
- [Summer 2022 Student Research](https://github.com/waggle-sensor/summer2022/blob/main/Tsai/Documentation.md)
- [Wes-Chirpstack](https://github.com/waggle-sensor/waggle-edge-stack/tree/main/kubernetes/wes-chirpstack)
- [Chirpstack Documentation](https://www.chirpstack.io/docs/index.html)
- [Minicom Documentation](https://linux.die.net/man/1/minicom)

