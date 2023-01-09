# CONTRIBUTING

## build

```sh
nix develop  # or use direnv or do the setup yourself, whatever
nix build    # or `make -j T=open_source`
```

where `T` is any directory under [`./config`](./config).

## flash

> **NOTE**: currently doesn't work, follow the Windows guide on the wiki instead

```sh
flashrom -p pony_spi:dev=/dev/ttyACM0 -w out/open_source/open_source.bin
```

## logs

> **NOTE**: also doesn't work; just prints garbage

```sh
minicom -D /dev/ttyACM0
```

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
