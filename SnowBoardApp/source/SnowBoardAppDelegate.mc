import Toybox.WatchUi;

class SnowBoardAppDelegate extends WatchUi.BehaviorDelegate {
    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // LE gomb (következő oldal)
    function onNextPage() {
        if (_view.isTracking()) {
            _view.nextScreen();
            return true;
        }
        return false;
    }

    // FEL gomb (előző oldal)
    function onPreviousPage() {
        if (_view.isTracking()) {
            _view.prevScreen();
            return true;
        }
        return false;
    }

    // START gomb kezelése
    function onSelect() {
        if (!_view.isTracking()) {
            _view.startTracking();
        } else {
            var menu = new WatchUi.Menu();
            menu.setTitle("Session vége?");
            menu.addItem("Mentés", :save);
            menu.addItem("Folytatás", :resume);
            menu.addItem("Elvetés", :discard);
            WatchUi.pushView(menu, new SnowBoardAppMenuDelegate(_view), WatchUi.SLIDE_UP);
        }
        return true;
    }

    function onBack() {
        if (_view.isTracking()) {
            _view.toggleManualPause();
            return true; 
        }
        return false;
    }

    // Érintés tiltása továbbra is aktív
    function onTap(evt) { return true; }
    function onSwipe(evt) { return true; }
    function onDrag(evt) { return true; }
    function onHold(evt) { return true; }
    function onRelease(evt) { return true; }
}