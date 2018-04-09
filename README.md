# diskburn

Simple shell script to test new HDDs.

## Usage

```sh
sudo diskburn /dev/sda /dev/sdb /dev/sdc
```

Warning: This will perform a destructive read/write test and delete
all data on `/dev/sda`, `/dev/sdb` and `/dev/sdc`!

## Copyright

Copyright (c) 2014-2018 Sebastian Boehm. See [LICENSE](LICENSE) for
details.
