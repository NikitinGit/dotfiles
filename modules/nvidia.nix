{
  nixosModule =
    { config, ... }:

    {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;

        open = true;
        nvidiaSettings = true;
        forceFullCompositionPipeline = true;
        package = config.boot.kernelPackages.nvidiaPackages.latest;

        powerManagement = {
          enable = false;
          finegrained = false;
        };
      };
    };
}
