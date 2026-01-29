import Toybox.Application;
import Toybox.WatchUi;

class SnowBoardAppApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new SnowBoardAppView();
        var delegate = new SnowBoardAppDelegate(view);
        return [ view, delegate ];
    }
}