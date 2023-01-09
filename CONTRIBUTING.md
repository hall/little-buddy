# CONTRIBUTING

## build

```sh
nix develop  # or use direnv or do the setup yourself, whatever
nix build    # or `make -j T=open_source`
```

where `T` is any directory under [`./config`](./config).

## flash

Flash both earbuds with [`bestool`](https://github.com/Ralim/bestool):

    for i in 0 1; do bestool write-image --port /dev/ttyACM$i result/little-buddy-*.bin; done

## logs

View logs over the serial port with

    minicom -D /dev/ttyACM0 -b 921600

## release

Create a new release by moving the "Unreleased" section in [`CHANGELOG.md`](./CHANGELOG.md) to a new version.
Once pushed the [`main.yml`](./.github/workflows/main.yml) workflow will create a new release.

## notes

> **NOTE**: upstream wrote this; leaving until I better understand

This is the core function:

```c
void vol_state_process(uint32_t ambient_db) {
    int volume = app_bt_stream_local_volume_get();
     TRACE(2,"ambient db: %d volume: %d ", ambient_db, volume);

     if((ambient_db < 52) && (volume > 10)) {
         app_bt_volumedown();
     }
     else if((ambient_db > 60) && (volume < 13)) {
         app_bt_volumeup();
     }
     else if((ambient_db > 72) && (volume < 15)) {
         app_bt_volumeup();
     }
}
```

If you need key switch control, set a global variable to control whether to call this function where `vol_state_process((uint32_t)db_sum);` is called.
