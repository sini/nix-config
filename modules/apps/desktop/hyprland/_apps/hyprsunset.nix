{

  services.hyprsunset = {
    enable = true;
    transitions = {
      sunrise = {
        calendar = "*-*-* 08:30:00";
        requests = [
          [
            "temperature"
            "6500"
          ]
          [ "gamma 100" ]
        ];
      };
      sunset = {
        calendar = "*-*-* 22:00:00";
        requests = [
          [
            "temperature"
            "4500"
          ]
        ];
      };
    };
  };

}
