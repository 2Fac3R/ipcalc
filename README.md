# Bash IPv4 Calculator

`ipcalc.sh` is a Bash IPv4 subnet calculator inspired by the [Jodies IP Calculator](https://jodies.de/ipcalc). It prints the address, netmask, wildcard mask, network, broadcast address, host range, host count, address class, and binary forms.

## Requirements

- Bash 4 or later

## Usage

```text
./ipcalc.sh ADDRESS [NETMASK [SUBNET_MASK [SUBNET_INDEX|ADDRESS]]]
```

`ADDRESS` is an IPv4 address. `NETMASK` and `SUBNET_MASK` accept:

- A CIDR prefix, with or without a slash (for example, `24` or `/24`)
- A dotted-decimal netmask (for example, `255.255.255.0`)
- A dotted-decimal inverse or wildcard mask (for example, `0.0.0.255`)

If `NETMASK` is omitted, the script uses the address's classful default: `/8` for Class A, `/16` for Class B, or `/24` for Class C and above.

The optional `SUBNET_MASK` describes smaller subnets within the network. The script lists the ranges for each subnet, up to 256 entries. If there are more than 256, it shows the first 256. Supply the final argument to select a single subnet by its zero-based index or by an IPv4 address within that subnet.

If `SUBNET_MASK` is broader than `NETMASK`, the script reports the containing supernet.

## What the output means

- **Address** is the input host or address. Its binary form shows the four IPv4 octets as eight-bit groups.
- **Netmask** marks which address bits identify the network (`1`) and which identify hosts (`0`). The `/prefix` is the number of leading network bits.
- **Wildcard** is the bitwise inverse of the netmask. It is commonly used in router access-control rules and also shows which bits can vary within the network.
- **Network** is the first address in the range, found by applying the netmask to the input address. Its host bits are all zero.
- **Broadcast** is the last address in an IPv4 subnet, with all host bits set. It is used to address all hosts on that subnet.
- **HostMin** and **HostMax** are the first and last assignable addresses in a typical subnet. For `/31` and `/32`, the script follows point-to-point and single-address conventions instead of subtracting network and broadcast addresses.
- **Hosts/Net** is the number of assignable addresses under those conventions: normally the total address count minus the network and broadcast addresses.
- **Class** is the historical classful category determined by the address's first bits. Modern networks use CIDR prefixes; the class is shown for reference and to explain the default mask when none is supplied.
- **Private Internet** marks addresses in the RFC 1918 private IPv4 ranges. These addresses are intended for private networks and are not globally routed as public addresses.
- **Binary columns** display each value as four eight-bit octets. Comparing the address with the netmask makes the network and host bits visible.
- **Subnets** divide the parent network into smaller networks by using a longer prefix. Each listed range gives the subnet's network address through its final address; the optional selector chooses one of these subnets.
- **Supernet** combines the input network with neighboring address space by using a shorter prefix.

## Examples

Calculate a network using a CIDR prefix:

```bash
./ipcalc.sh 172.14.15.16 17
```

Use a dotted-decimal mask:

```bash
./ipcalc.sh 192.168.0.1 255.255.255.0
```

Use an inverse mask:

```bash
./ipcalc.sh 192.168.0.1 0.0.0.255
```

Show `/26` subnets inside a `/24` network:

```bash
./ipcalc.sh 192.168.0.1 24 26
```

Show only the third subnet (indices start at zero):

```bash
./ipcalc.sh 192.168.0.1 24 26 2
```

Get help:

```bash
./ipcalc.sh --help
```

## Notes

- `/31` networks are treated as having two usable endpoint addresses, and `/32` networks as having one address.
- The private-network note recognizes RFC 1918 ranges: `10.0.0.0/8`, `172.16.0.0/12`, and `192.168.0.0/16`.
