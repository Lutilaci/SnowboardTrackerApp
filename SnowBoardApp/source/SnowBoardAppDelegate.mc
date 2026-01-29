import Toybox.WatchUi;

class SnowBoardAppDelegate extends WatchUi.BehaviorDelegate {
    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // A fizikai START/SELECT gomb kezelése
    function onSelect() {
        if (!_view.isTracking()) {
            // Első gombnyomás: Indítás
            _view.startTracking();
        } else {
            // Ha már fut a session, a Start gomb megnyitja a befejező menüt
            var menu = new WatchUi.Menu();
            menu.setTitle("Session vége?");
            menu.addItem("Mentés", :save);
            menu.addItem("Folytatás", :resume);
            menu.addItem("Elvetés (Törlés)", :discard);
            
            WatchUi.pushView(menu, new SnowBoardAppMenuDelegate(_view), WatchUi.SLIDE_UP);
        }
        WatchUi.requestUpdate();
        return true;
    }

    // A BACK gomb kezelése
    function onBack() {
        if (_view.isTracking()) {
            // Ha fut a rögzítés, a Back gomb ne lépjen ki, 
            // hanem kényszerítsen szünetet vagy ne csináljon semmit
            _view.toggleManualPause();
            return true; 
        }
        return false; // Ha nem rögzít, engedélyezi a kilépést
    }

    // --- ÉRINTŐKÉPERNYŐ TILTÁSA ---
    // Az alábbi függvények felülbírálásával és 'true' (elkapva) visszatéréssel 
    // gyakorlatilag "lenyeljük" az érintéseket, így az óra nem reagál rájuk.

    function onTap(evt) { return true; }
    function onSwipe(evt) { return true; }
    function onHold(evt) { return true; }
}