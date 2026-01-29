import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;

class SnowBoardSummaryView extends WatchUi.View {
    private var _runs as Number;
    private var _lifts as Number;
    private var _maxSpeed as Float;
    private var _totalDescend as Float;
    private var _distance as Float;

    function initialize(runs as Number, lifts as Number, maxSpeed as Float, totalDescend as Float, distance as Float) {
        View.initialize();
        _runs = runs;
        _lifts = lifts;
        _maxSpeed = maxSpeed;
        _totalDescend = totalDescend;
        _distance = distance;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (h * 0.15).toNumber(), Graphics.FONT_MEDIUM, "ÖSSZESÍTŐ", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.2).toNumber(), (h * 0.25).toNumber(), (w * 0.8).toNumber(), (h * 0.25).toNumber());

        var yStart = h * 0.30;
        var ySpace = h * 0.10;

        drawSummaryRow(dc, centerX, yStart.toNumber(), "MENETEK:", _runs.toString());
        drawSummaryRow(dc, centerX, (yStart + ySpace).toNumber(), "LIFTEK:", _lifts.toString());
        drawSummaryRow(dc, centerX, (yStart + (ySpace * 2)).toNumber(), "TÁV:", _distance.format("%.2f") + " km");
        drawSummaryRow(dc, centerX, (yStart + (ySpace * 3)).toNumber(), "MAX SEB:", _maxSpeed.format("%.1f") + " km/h");
        drawSummaryRow(dc, centerX, (yStart + (ySpace * 4)).toNumber(), "SÜLLYEDÉS:", _totalDescend.format("%d") + " m");

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (h * 0.85).toNumber(), Graphics.FONT_XTINY, "START: KILÉPÉS", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSummaryRow(dc as Dc, x as Number, y as Number, label as String, value as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - 10, y, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 10, y, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_LEFT);
    }
}

class SnowBoardSummaryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onSelect() as Boolean {
        System.exit();
        return true; 
    }
    
    function onBack() as Boolean {
        System.exit();
        return true; 
    }
}