import Toybox.Lang;
import Toybox.WatchUi;

class SnowBoardAppDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new SnowBoardAppMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}