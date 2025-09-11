{
  # Simple test application
  applications.test = {
    namespace = "test";
    createNamespace = true;

    resources = {
      # Define a simple config map
      configMaps.test-config.data = {
        "test.txt" = "Hello from nixidy!";
      };
    };
  };
}
