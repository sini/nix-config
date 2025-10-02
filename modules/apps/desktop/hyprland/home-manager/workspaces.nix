{
  flake.features.hyprland.home =
    let
      editor = [ "nvim.desktop" ];
      browser = [ "firefox.desktop" ];
      #fileBrowser = [ "yazi.desktop" ];
      imageViewer = [ "org.gnome.Loupe.desktop" ]; # TODO: change to sxiv/feh
      # https://www.youtube.com/watch?v=GYW9i_u5PYs
      pdfViewer = [ "org.pwmt.zathura.desktop" ];
      associations = {
        "text/x-dbus-service" = editor;
        "image/jpeg" = imageViewer;
        "image/png" = imageViewer;
        "image/gif" = imageViewer;
        "image/webp" = imageViewer;
        "image/tiff" = imageViewer;
        "image/x-tga" = imageViewer;
        "image/vnd-ms.dds" = imageViewer;
        "image/x-dds" = imageViewer;
        "image/bmp" = imageViewer;
        "image/vnd.microsoft.icon" = imageViewer;
        "image/vnd.radiance" = imageViewer;
        "image/x-exr" = imageViewer;
        "image/x-portable-bitmap" = imageViewer;
        "image/x-portable-graymap" = imageViewer;
        "image/x-portable-pixmap" = imageViewer;
        "image/x-portable-anymap" = imageViewer;
        "image/x-qoi" = imageViewer;
        "image/svg+xml" = imageViewer;
        "image/svg+xml-compressed" = imageViewer;
        "image/avif" = imageViewer;
        "image/heic" = imageViewer;
        "image/jxl" = imageViewer;
        "application/pdf" = pdfViewer;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/chrome" = browser;
        "text/html" = browser;
        "application/x-extension-htm" = browser;
        "application/x-extension-html" = browser;
        "application/x-extension-shtml" = browser;
        "application/xhtml+xml" = browser;
        "application/x-extension-xhtml" = browser;
        "application/x-extension-xht" = browser;
        # TODO: fix
        # "inode/directory" = fileBrowser;
      };
    in
    {
      xdg = {
        configFile."mimeapps.list".force = true;
        mimeApps = {
          enable = true;
          defaultApplications = associations;
          associations.added = associations;
        };
      };
    };
}
