# diskburn

Simple shell script to test new HDDs.

## Usage

```sh
sudo diskburn /dev/sda /dev/sdb /dev/sdc
```

Warning: This will perform a destructive read/write test and delete
all data on `/dev/sda`, `/dev/sdb` and `/dev/sdc`!

## Dependencies

Diskburn needs a couple of standard utilities in order to test disks:

- `badblocks(8)`
- `smartctl(8)`
- `zcav(8)`

On Debian-based systems, these can be installed using the following
command:

```sh
sudo apt install e2fsprogs smartmontools bonnie++
```

Also, if `gnuplot(1)` is installed, diskburn produces a HDD throughput
plot. If `gnuplot` is not installed, a `gnuplot` script is written to
the test directory which you can then run on another system.

## Copyright

Copyright (c) 2014-2020 Sebastian Boehm. See [LICENSE](LICENSE) for
details.
