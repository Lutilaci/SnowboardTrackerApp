import Toybox.WatchUi;

class SnowBoardAppDelegate extends WatchUi.BehaviorDelegate {
    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        if (!_view.isTracking()) {
            _view.startTracking();
        } else {
            _view.toggleManualPause();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // A vissza gomb megnyomásakor leállítjuk és mentjük az edzést
    function onBack() {
        if (_view.isTracking()) {
            _view.stopAndSave();
            WatchUi.popView(WatchUi.SLIDE_DOWN); // Kilépés az appból
            return true;
        }
        return false;
    }
}