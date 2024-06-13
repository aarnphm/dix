{ config, lib, pkgs, ... }:
with lib;
let
  karabinerConfig = {
    "global" = {
      "ask_for_confirmation_before_quitting" = true;
      "check_for_updates_on_startup" = false;
      "show_in_menu_bar" = true;
      "show_profile_name_in_menu_bar" = false;
      "unsafe_ui" = true;
    };
    "profiles" = [
      {
        "complex_modifications" = {
          "parameters" = {
            "basic.simultaneous_threshold_milliseconds" = 50;
            "basic.to_delayed_action_delay_milliseconds" = 500;
            "basic.to_if_alone_timeout_milliseconds" = 1000;
            "basic.to_if_held_down_threshold_milliseconds" = 500;
            "mouse_motion_to_scroll.speed" = 100;
          };
          "rules" = [ ];
        };
        "devices" = [
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = true;
              "is_pointing_device" = false;
              "product_id" = 835;
              "vendor_id" = 1452;
            };
            "ignore" = false;
            "manipulate_caps_lock_led" = true;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = false;
              "is_pointing_device" = true;
              "product_id" = 835;
              "vendor_id" = 1452;
            };
            "ignore" = true;
            "manipulate_caps_lock_led" = false;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = true;
              "is_pointing_device" = false;
              "product_id" = 50503;
              "vendor_id" = 1133;
            };
            "ignore" = false;
            "manipulate_caps_lock_led" = true;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = false;
              "is_pointing_device" = true;
              "product_id" = 50503;
              "vendor_id" = 1133;
            };
            "ignore" = true;
            "manipulate_caps_lock_led" = false;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
        ];
        "fn_function_keys" = [
          {
            "from" = {
              "key_code" = "f1";
            };
            "to" = [
              {
                "consumer_key_code" = "display_brightness_decrement";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f2";
            };
            "to" = [
              {
                "consumer_key_code" = "display_brightness_increment";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f3";
            };
            "to" = [
              {
                "apple_vendor_keyboard_key_code" = "mission_control";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f4";
            };
            "to" = [
              {
                "apple_vendor_keyboard_key_code" = "spotlight";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f5";
            };
            "to" = [
              {
                "consumer_key_code" = "dictation";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f6";
            };
            "to" = [
              {
                "key_code" = "f6";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f7";
            };
            "to" = [
              {
                "consumer_key_code" = "rewind";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f8";
            };
            "to" = [
              {
                "consumer_key_code" = "play_or_pause";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f9";
            };
            "to" = [
              {
                "consumer_key_code" = "fast_forward";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f10";
            };
            "to" = [
              {
                "consumer_key_code" = "mute";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f11";
            };
            "to" = [
              {
                "consumer_key_code" = "volume_decrement";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f12";
            };
            "to" = [
              {
                "consumer_key_code" = "volume_increment";
              }
            ];
          }
        ];
        name = "default";
        parameters = {
          "delay_milliseconds_before_open_device" = 1000;
        };
        "selected" = false;
        "simple_modifications" = [ ];
        "virtual_hid_keyboard" = {
          "country_code" = 0;
          "indicate_sticky_modifier_keys_state" = true;
          "mouse_key_xy_scale" = 100;
        };
      }
      {
        "complex_modifications" = {
          "parameters" = {
            "basic.simultaneous_threshold_milliseconds" = 50;
            "basic.to_delayed_action_delay_milliseconds" = 500;
            "basic.to_if_alone_timeout_milliseconds" = 1000;
            "basic.to_if_held_down_threshold_milliseconds" = 500;
            "mouse_motion_to_scroll.speed" = 100;
          };
          "rules" = [ ];
        };
        "devices" = [
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = true;
              "is_pointing_device" = false;
              "product_id" = 835;
              "vendor_id" = 1452;
            };
            "ignore" = false;
            "manipulate_caps_lock_led" = true;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [
              {
                "from" = {
                  "key_code" = "caps_lock";
                };
                "to" = [
                  {
                    "key_code" = "comma";
                  }
                ];
              }
            ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = false;
              "is_pointing_device" = true;
              "product_id" = 835;
              "vendor_id" = 1452;
            };
            "ignore" = true;
            "manipulate_caps_lock_led" = false;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = true;
              "is_pointing_device" = false;
              "product_id" = 50503;
              "vendor_id" = 1133;
            };
            "ignore" = false;
            "manipulate_caps_lock_led" = true;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
          {
            "disable_built_in_keyboard_if_exists" = false;
            "fn_function_keys" = [ ];
            "game_pad_swap_sticks" = false;
            "identifiers" = {
              "is_game_pad" = false;
              "is_keyboard" = false;
              "is_pointing_device" = true;
              "product_id" = 50503;
              "vendor_id" = 1133;
            };
            "ignore" = true;
            "manipulate_caps_lock_led" = false;
            "mouse_flip_horizontal_wheel" = false;
            "mouse_flip_vertical_wheel" = false;
            "mouse_flip_x" = false;
            "mouse_flip_y" = false;
            "mouse_swap_wheels" = false;
            "mouse_swap_xy" = false;
            "simple_modifications" = [ ];
            "treat_as_built_in_keyboard" = false;
          }
        ];
        "fn_function_keys" = [
          {
            "from" = {
              "key_code" = "f1";
            };
            "to" = [
              {
                "consumer_key_code" = "display_brightness_decrement";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f2";
            };
            "to" = [
              {
                "consumer_key_code" = "display_brightness_increment";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f3";
            };
            "to" = [
              {
                "apple_vendor_keyboard_key_code" = "mission_control";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f4";
            };
            "to" = [
              {
                "apple_vendor_keyboard_key_code" = "spotlight";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f5";
            };
            "to" = [
              {
                "consumer_key_code" = "dictation";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f6";
            };
            "to" = [
              {
                "key_code" = "f6";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f7";
            };
            "to" = [
              {
                "consumer_key_code" = "rewind";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f8";
            };
            "to" = [
              {
                "consumer_key_code" = "play_or_pause";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f9";
            };
            "to" = [
              {
                "consumer_key_code" = "fast_forward";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f10";
            };
            "to" = [
              {
                "consumer_key_code" = "mute";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f11";
            };
            "to" = [
              {
                "consumer_key_code" = "volume_decrement";
              }
            ];
          }
          {
            "from" = {
              "key_code" = "f12";
            };
            "to" = [
              {
                "consumer_key_code" = "volume_increment";
              }
            ];
          }
        ];
        "name" = "afp";
        "parameters" = {
          "delay_milliseconds_before_open_device" = 1000;
        };
        "selected" = true;
        "simple_modifications" = [ ];
        "virtual_hid_keyboard" = {
          "country_code" = 0;
          "indicate_sticky_modifier_keys_state" = true;
          "mouse_key_xy_scale" = 100;
        };
      }
    ];
  };
in
{
  options.karabiner = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''karabiner configuration'';
    };
  };

  config = mkIf (config.karabiner.enable && pkgs.stdenv.isDarwin) {
    xdg = {
      enable = true;
      configFile = {
        "karabiner/karabiner.json".source = pkgs.writeText "karabiner-keymap" (builtins.toJSON karabinerConfig);
      };
    };
  };
}