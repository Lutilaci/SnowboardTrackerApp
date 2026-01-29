import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class SnowBoardAppMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _view as SnowBoardAppView;

    // Az inicializáláskor átvesszük a fő View-t, hogy elérjük az adatmezőket
    function initialize(view as SnowBoardAppView) {
        MenuInputDelegate.initialize();
        _view = view;
    }

    // A menüpont kiválasztásakor lefutó logika
    function onMenuItem(item as Symbol) as Void {
        if (item == :save) {
            // 1. Összegyűjtjük az összesített adatokat a View-ból
            var runs = _view.getRunCount();
            var lifts = _view.getLiftCount();
            var maxSpeed = _view.getMaxSpeed();
            var descend = _view.getTotalDescend();
            var distance = _view.getTotalDistance();

            // 2. Leállítjuk és elmentjük a rögzítést (FIT fájl generálása)
            _view.stopAndSave();
            
            // 3. Átváltunk az Összegző képernyőre (SummaryView)
            // Átadjuk az összes kért adatot a konstruktornak
            WatchUi.switchToView(
                new SnowBoardSummaryView(runs, lifts, maxSpeed, descend, distance), 
                new SnowBoardSummaryDelegate(), 
                WatchUi.SLIDE_IMMEDIATE
            );
            
        } else if (item == :discard) {
            // Ha a felhasználó elveti (törli) a session-t
            _view.stopAndDiscard();
            
            // Azonnali kilépés az alkalmazásból mentés nélkül
            System.exit();
            
        } else if (item == :resume) {
            // Ha a "Folytatás"-t választja, egyszerűen bezárjuk a menüt
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}