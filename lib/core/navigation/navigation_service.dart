/// Service for handling navigation between screens and showing destinations on map
class NavigationService {
  NavigationService._();
  
  static final NavigationService instance = NavigationService._();
  
  // Callback function to show destination on map
  Function(int)? _showDestinationOnMapCallback;
  
  /// Register callback for showing destination on map
  void registerShowDestinationCallback(Function(int) callback) {
    _showDestinationOnMapCallback = callback;
  }
  
  /// Show destination on map using registered callback
  void showDestinationOnMap(int destinationId) {
    _showDestinationOnMapCallback?.call(destinationId);
  }
  
  /// Clear the callback
  void clearCallback() {
    _showDestinationOnMapCallback = null;
  }
}