{
  flake.features.mpv.home =
    { pkgs, ... }:
    let
      shaders = "${pkgs.mpv-shim-default-shaders}/share/mpv-shim-default-shaders/shaders/";
      # https://github.com/iwalton3/default-shader-pack/blob/b573551f021f942d6c7546391c7c994bb435ee6c/pack-next.json
      profiles = {
        fsr = {
          name = "AMD FidelityFX Super Resolution";
          settings = {
            glsl-shader = "${shaders}FSR.glsl";
          };
        };
        cas = {
          name = "AMD FidelityFX Contrast Adaptive Sharpening";
          settings = {
            glsl-shader = "${shaders}CAS-scaled.glsl";
          };
        };
        fsr-cas = {
          name = "AMD FidelityFX Super Resolution + Contrast Adaptive Sharpening";
          settings = {
            glsl-shaders = [
              "${shaders}FSR.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}CAS-scaled.glsl"
            ];
          };
        };
        generic = {
          name = "FSRCNNX";
          settings = {
            dscale = "mitchell";
            cscale = "mitchell";
            glsl-shaders = [
              "${shaders}FSRCNNX_x2_16-0-4-1.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}SSimDownscaler.glsl"
              "${shaders}KrigBilateral.glsl"
            ];
          };
        };
        generic-high = {
          name = "FSRCNNX x16";
          settings = {
            dscale = "mitchell";
            cscale = "mitchell";
            glsl-shaders = [
              "${shaders}FSRCNNX_x2_8-0-4-1.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}SSimDownscaler.glsl"
              "${shaders}KrigBilateral.glsl"
            ];
          };
        };
        nnedi-high = {
          name = "NNEDI3 (64 Neurons)";
          settings = {
            dscale = "mitchell";
            cscale = "mitchell";
            glsl-shaders = [
              "${shaders}nnedi3-nns64-win8x6.hook"
            ];
            glsl-shaders-append = [
              "${shaders}SSimDownscaler.glsl"
              "${shaders}KrigBilateral.glsl"
            ];
          };
        };
        nnedi-very-high = {
          name = "NNEDI3 High (128 Neurons)";
          settings = {
            dscale = "mitchell";
            cscale = "mitchell";
            glsl-shaders = [
              "${shaders}nnedi3-nns128-win8x6.hook"
            ];
            glsl-shaders-append = [
              "${shaders}SSimDownscaler.glsl"
              "${shaders}KrigBilateral.glsl"
            ];
          };
        };
        anime4k-high-a = {
          name = "Anime4K A (HQ) - For Very Blurry/Compressed";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_VL.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-high-b = {
          name = "Anime4K B (HQ) - For Blurry/Ringing";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}CAS-scaled.glsl"
              "${shaders}Anime4K_Restore_CNN_Soft_VL.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-high-c = {
          name = "Anime4K C (HQ) - For Crisp/Sharp";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Upscale_Denoise_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-high-aa = {
          name = "Anime4K AA (HQ) - For Very Blurry/Compressed";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}CAS-scaled.glsl"
              "${shaders}Anime4K_Restore_CNN_VL.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-high-bb = {
          name = "Anime4K BB (HQ) - For Blurry/Ringing";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_Soft_VL.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_Soft_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-high-ca = {
          name = "Anime4K CA (HQ) - For Crisp/Sharp";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Upscale_Denoise_CNN_x2_VL.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
            ];
          };
        };
        anime4k-fast-a = {
          name = "Anime4K A (Fast) - For Very Blurry/Compressed";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
        anime4k-fast-b = {
          name = "Anime4K B (Fast) - For Blurry/Ringing";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_Soft_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
        anime4k-fast-c = {
          name = "Anime4K C (Fast) - For Crisp/Sharp";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Upscale_Denoise_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
        anime4k-fast-aa = {
          name = "Anime4K AA (Fast) - For Very Blurry/Compressed";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_S.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
        anime4k-fast-bb = {
          name = "Anime4K BB (Fast) - For Blurry/Ringing";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Restore_CNN_Soft_M.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_Soft_S.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
        anime4k-fast-cc = {
          name = "Anime4K CA (Fast) - For Crisp/Sharp";
          settings = {
            glsl-shaders = [
              "${shaders}Anime4K_Clamp_Highlights.glsl"
            ];
            glsl-shaders-append = [
              "${shaders}Anime4K_Upscale_Denoise_CNN_x2_M.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x2.glsl"
              "${shaders}Anime4K_AutoDownscalePre_x4.glsl"
              "${shaders}Anime4K_Restore_CNN_S.glsl"
              "${shaders}Anime4K_Upscale_CNN_x2_S.glsl"
            ];
          };
        };
      };
    in
    {
      programs.mpv = {
        enable = true;

        config = {
          # UI
          autofit = "70%";

          # Video
          vo = "gpu-next";
          gpu-api = "vulkan";
          hwdec = "auto-safe";

          # Audio
          ao = "pipewire";
          alang = "jpn,jap,ja,jp,eng,en";

          # Subtitles
          sub-auto = "fuzzy";

          # Screenshots
          screenshot-directory = "~/Pictures";
          screenshot-template = "mpv-%f-%wH.%wM.%wS.%wT-#%#00n"; # name-hour-minute-second-millisecond-ssnumb

          ytdl-format = "bestvideo+bestaudio";
          slang = "eng,en";
          hwdec-codecs = "all";
        };

        bindings = {
          # https://github.com/mpv-player/mpv/blob/master/etc/input.conf
          "MOUSE_BTN2" = "script-binding uosc/menu-blurred";
          "tab" = "script-binding uosc/toggle-ui";
          "Shift+ENTER" = "script-binding uosc/download-subtitles";

          a = "cycle audio";
          s = "cycle sub";
          WHEEL_UP = "add volume 2.5";
          WHEEL_DOWN = "add volume -2.5";
          UP = "add volume 2.5";
          DOWN = "add volume -2.5";
          ENTER = "ignore";
          "=" = "add video-zoom 0.1";
          "-" = "add video-zoom -0.1";
          "alt+=" = "add video-rotate 90";
          "alt+-" = "add video-rotate -90";
        };

        scripts = with pkgs.mpvScripts; [
          inhibit-gnome # do not let gnome sleep during playback
          mpris # integrate with media controls
          autoload # load playlist entries from play dir
          uosc
          thumbfast
          sponsorblock
          quality-menu
        ];

        scriptOpts = {
          uosc = {
            # https://github.com/tomasklaen/uosc/blob/main/src/uosc.conf
            controls = "subtitles,<has_chapter>chapters,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,space,menu";
          };

          autoload = {
            disabled = false;
            images = false;
            videos = true;
            audio = true;
            ignore_hidden = true;
            same_type = true;
            directory_mode = "ignore";
          };
        };

        # https://github.com/tomasklaen/uosc?tab=readme-ov-file#menu-1
        extraInput = ''
          ` script-binding console/enable #! Console

          g cycle interpolation #! Video > Interpolation
          d cycle deinterlace #! Video > Toggle Deinterlace
          [ add speed +0.1; script-binding uosc/flash-speed #! Video > Speed > Increase Speed
          ] add speed -0.1; script-binding uosc/flash-speed #! Video > Speed > Decrease Speed
          BS set speed 1; script-binding uosc/flash-speed #! Video > Speed > Reset Speed
          # set video-aspect-override "-1" #! Video > Aspect Ratio > Default
          # set video-aspect-override "16:9" #! Video > Aspect Ratio > 16:9
          # set video-aspect-override "4:3" #! Video > Aspect Ratio > 4:3
          # set video-aspect-override "2.35:1" #! Video > Aspect Ratio > 2.35:1
          # vf toggle vflip #! Video > Flip > Vertical
          # vf toggle hflip #! Video > Flip > Horizontal
          b cycle-values deband "yes" "no" #! Video > Deband > Toggle Deband
          # cycle-values deband-threshold "35" "45" "60\ show-text "Deband: ''${deband-iterations}:''${deband-threshold}:''${deband-range}:''${deband-grain}" 1000 #! Video > Deband > Deband (Weak)
          # cycle-values deband-range "20" "25" "30\ show-text "Deband: ''${deband-iterations}:''${deband-threshold}:''${deband-range}:''${deband-grain}" 1000 #! Video > Deband > Deband (Medium)
          # cycle-values deband-grain "5" "15" "30\ show-text "Deband: ''${deband-iterations}:''${deband-threshold}:''${deband-range}:''${deband-grain}" 1000 #! Video > Deband > Deband (Strong)

          # script-binding uosc/audio-device #! Audio > Devices
          F1 af toggle "lavfi=[loudnorm=I=-14:TP=-3:LRA=4]'"; show-text "''${af}" #! Audio > Dialogue
          # af clr "" #! Audio > Clear Filters
          # script-binding afilter/toggle-eqr #! Audio > Toggle Equalizer
          a cycle audio-normalize-downmix #! Audio > Toggle Normalize
          # script-binding afilter/toggle-dnm #! Audio > Toggle Normalizer
          # script-binding afilter/toggle-drc #! Audio > Toggle Compressor
          Ctrl++ add audio-delay +0.10 #! Audio > Delay > Increase Audio Delay
          Ctrl+- add audio-delay -0.10 #! Audio > Delay > Decrease Audio Delay
          # set audio-delay 0 #! Audio > Delay > Reset Audio Delay

          Shift+g add sub-scale +0.05 #! Subtitles > Scale > Increase Subtitle Scale
          Shift+f add sub-scale -0.05 #! Subtitles > Scale > Decrease Subtitle Scale
          # set sub-scale 1 #! Subtitles > Scale > Reset Subtitle Scale
          : add sub-pos -1 #! Subtitles > Position > Move Subtitle Up
          " add sub-pos +1 #! Subtitles > Position > Move Subtitle Down
          # set sub-pos 100 #! Subtitles > Position > Reset Subtitle Position
          z add sub-delay -0.1 #! Subtitles > Delay > Decrease Subtitles Delay
          Z add sub-delay 0.1 #! Subtitles > Delay > Increase Subtitles Delay
          # set sub-delay 0 #! Subtitles > Delay > Reset Subtitles Delay

          # script-binding sview/shader-view #! Profiles > Show Loaded Shaders
          CTRL+0 change-list glsl-shaders clr all; show-text "Shaders cleared" #! Profiles > Clear All Shaders
          # #! Profiles > ---
          # apply-profile fsr; show-text "Profile: ${profiles.fsr.name}" #! Profiles > ${profiles.fsr.name}
          # apply-profile cas; show-text "Profile: ${profiles.cas.name}" #! Profiles > ${profiles.cas.name}
          CTRL+1 apply-profile fsr-cas; show-text "Profile: ${profiles.fsr-cas.name}" #! Profiles > ${profiles.fsr-cas.name}
          # apply-profile genreric #! Profiles > ${profiles.generic.name}
          CTRL+2 apply-profile generic-high; show-text "Profile: ${profiles.generic-high.name}" #! Profiles > ${profiles.generic-high.name}
          # apply-profile nnedi-high; show-text "Profile: ${profiles.nnedi-high.name}" #! Profiles > ${profiles.nnedi-high.name}
          CTRL+3 apply-profile nnedi-very-high; show-text "Profile: ${profiles.nnedi-very-high.name}" #! Profiles > ${profiles.nnedi-very-high.name}
          CTRL+4 apply-profile anime4k-high-a; show-text "Profile: ${profiles.anime4k-high-a.name}" #! Profiles > ${profiles.anime4k-high-a.name}
          CTRL+5 apply-profile anime4k-high-b; show-text "Profile: ${profiles.anime4k-high-b.name}" #! Profiles > ${profiles.anime4k-high-b.name}
          CTRL+6 apply-profile anime4k-high-c; show-text "Profile: ${profiles.anime4k-high-c.name}" #! Profiles > ${profiles.anime4k-high-c.name}
          CTRL+7 apply-profile anime4k-high-aa; show-text "Profile: ${profiles.anime4k-high-aa.name}" #! Profiles > ${profiles.anime4k-high-aa.name}
          CTRL+8 apply-profile anime4k-high-bb; show-text "Profile: ${profiles.anime4k-high-bb.name}" #! Profiles > ${profiles.anime4k-high-bb.name}
          CTRL+9 apply-profile anime4k-high-ca; show-text "Profile: ${profiles.anime4k-high-ca.name}" #! Profiles > ${profiles.anime4k-high-ca.name}
          # apply-profile anime4k-fast-a; show-text "Profile: ${profiles.anime4k-fast-a.name}" #! Profiles > ${profiles.anime4k-fast-a.name}
          # apply-profile anime4k-fast-b; show-text "Profile: ${profiles.anime4k-fast-b.name}" #! Profiles > ${profiles.anime4k-fast-b.name}
          # apply-profile anime4k-fast-c; show-text "Profile: ${profiles.anime4k-fast-c.name}" #! Profiles > ${profiles.anime4k-fast-c.name}
          # apply-profile anime4k-fast-aa; show-text "Profile: ${profiles.anime4k-fast-aa.name}" #! Profiles > ${profiles.anime4k-fast-aa.name}
          # apply-profile anime4k-fast-bb; show-text "Profile: ${profiles.anime4k-fast-bb.name}" #! Profiles > ${profiles.anime4k-fast-bb.name}
          # apply-profile anime4k-fast-cc; show-text "Profile: ${profiles.anime4k-fast-cc.name}" #! Profiles > ${profiles.anime4k-fast-cc.name}
        '';

        defaultProfiles = [ "high-quality" ]; # https://github.com/mpv-player/mpv/blob/master/etc/builtin.conf

        profiles = {
          fsr = profiles.fsr.settings;
          cas = profiles.cas.settings;
          fsr-cas = profiles.fsr-cas.settings;
          anime4k-high-a = profiles.anime4k-high-a.settings;
          anime4k-high-b = profiles.anime4k-high-b.settings;
          anime4k-high-c = profiles.anime4k-high-c.settings;
          anime4k-high-aa = profiles.anime4k-high-aa.settings;
          anime4k-high-bb = profiles.anime4k-high-bb.settings;
          anime4k-high-ca = profiles.anime4k-high-ca.settings;
          anime4k-fast-a = profiles.anime4k-fast-a.settings;
          anime4k-fast-b = profiles.anime4k-fast-b.settings;
          anime4k-fast-c = profiles.anime4k-fast-c.settings;
          anime4k-fast-aa = profiles.anime4k-fast-aa.settings;
          anime4k-fast-bb = profiles.anime4k-fast-bb.settings;
          anime4k-fast-cc = profiles.anime4k-fast-cc.settings;
          genreric = profiles.generic.settings;
          generic-high = profiles.generic-high.settings;
          nnedi-high = profiles.nnedi-high.settings;
          nnedi-very-high = profiles.nnedi-very-high.settings;
        };
      };
    };
}
