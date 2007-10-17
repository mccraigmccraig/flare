package flare.display
{
	import flash.display.Bitmap;
	import flash.text.TextField;
	import flash.display.BitmapData;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;
	import flash.filters.BlurFilter;
	import flash.display.Shape;
	import flash.geom.Rectangle;
	import flash.display.DisplayObject;
	import flare.display.DirtySprite;

	/**
	 * A Sprite representing a text label.
	 * TextSprites support multiple forms of text representation: bitmapped
	 * text, embedded font text, and standard (device font) text. This allows
	 * flexibility in how text labels are handled. For example, by default,
	 * text fields using device fonts do not support alpha blending or
	 * rotation. By using a TextSprite in BITMAP mode, the text is rendered
	 * out to a bitmap which can then be alpha blended.
	 */
	public class TextSprite extends DirtySprite
	{
		// vertical anchors
		/**
		 * Constant for vertically aligning the top of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const TOP:int = 0;
		/**
		 * Constant for vertically aligning the middle of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const MIDDLE:int = 1;
		/**
		 * Constant for vertically aligning the bottom of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const BOTTOM:int = 2;

		// horizontal anchors
		/**
		 * Constant for horizontally aligning the left of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const LEFT:int = 0;
		/**
		 * Constant for horizontally aligning the center of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const CENTER:int = 1;
		/**
		 * Constant for horizontally aligning the right of the text field
		 * to a TextSprite's y-coordinate.
		 */
		public static const RIGHT:int = 2;
		
		// text handling modes
		/**
		 * Constant indicating that text should be rendered using a TextField
		 * instance using device fonts.
		 */
		public static const DEVICE:uint = 0;
		/**
		 * Constant indicating that text should be rendered using a TextField
		 * instance using embedded fonts. For this mode to work, the fonts
		 * used must be embedded in your application SWF file.
		 */
		public static const EMBED:uint = 1;
		/**
		 * Constant indicating that text should be rendered into a Bitmap
		 * instance.
		 */
		public static const BITMAP:uint = 2;
		
		private var _mode:int = -1;
		private var _bmap:Bitmap;
		private var _mask:Shape;
		private var _tf:TextField;
		private var _fmt:TextFormat;
		private var _locked:Boolean = false;
		private var _maskColor:uint = 0xFFFFFF;
		
		private var _hAnchor:int = LEFT;
		private var _vAnchor:int = TOP;
		
		/**
		 * Gets the alpha value for a rectangular mask shape that is present
		 * when the text mode is DEVICE.
		 */
		public function get maskAlpha():Number {
			return _mask != null ? _mask.alpha : NaN;
		}
		/**
		 * Sets the alpha value for a rectangular mask shape that is present
		 * when the text mode is DEVICE.
		 */
		public function set maskAlpha(a:Number):void {
			if (_mask != null) _mask.alpha = a;
		}
		
		/**
		 * Gets the fill color for a rectangular mask shape that is present
		 * when the text mode is DEVICE.
		 */
		public function get maskColor():uint { return _maskColor; }
		/**
		 * Sets the fill color for a rectangular mask shape that is present
		 * when the text mode is DEVICE.
		 */
		public function set maskColor(c:uint):void {
			if (_maskColor != c) {
				_maskColor = c;
				if (_mode == DEVICE) dirty();
			}
		}
		
		/**
		 * The TextField instance backing this TextSprite.
		 */
		public function get textField():TextField { return _tf; }
		
		/**
		 * The text rendering mode for this TextSprite, one of BITMAP,
		 * DEVICE, or EMBED.
		 */
		public function get textMode():int { return _mode; }
		public function set textMode(mode:int):void {
			setMode(mode); //dirty();
		}
		
		/**
		 * The text string drawn by this TextSprite.
		 */
		public function get text():String { return _tf.text; }
		public function set text(txt:String):void {
			if (_tf.text != txt) {
				_tf.text = txt;
				if (_fmt!=null) _tf.setTextFormat(_fmt);
				dirty();
			}
		}
		
		/**
		 * The horizontal anchor for the text, one of LEFT, RIGHT, or CENTER.
		 * This setting determines how the text is horizontally aligned with
		 * respect to this TextSprite's (x,y) location.
		 */
		public function get horizontalAnchor():int { return _hAnchor; }
		public function set horizontalAnchor(a:int):void { 
			if (_hAnchor != a) { _hAnchor = a; layout(); }
		}
		
		/**
		 * The vertical anchor for the text, one of TOP, BOTTOM, or MIDDLE.
		 * This setting determines how the text is vertically aligned with
		 * respect to this TextSprite's (x,y) location.
		 */
		public function get verticalAnchor():int { return _vAnchor; }
		public function set verticalAnchor(a:int):void {
			if (_vAnchor != a) { _vAnchor = a; layout(); }
		}
		
		// --------------------------------------------------------------------
		
		/**
		 * Creates a new TextSprite instance.
		 * @param text the text string for this label
		 * @param format the TextFormat determining font family, size, and style
		 * @param mode the text rendering mode to use (BITMAP by default)
		 */
		public function TextSprite(text:String=null, format:TextFormat=null, mode:int=BITMAP) {
			_tf = new TextField();
			_tf.autoSize = TextFieldAutoSize.LEFT;
			if (text != null) _tf.text = text;
			_fmt = format;
			if (format != null) _tf.setTextFormat(format);
			_bmap = new Bitmap();
			setMode(mode);
			dirty();
		}
		
		protected function setMode(mode:int):void
		{
			if (mode == _mode) return; // nothing to do
			
			switch (_mode) {
				case BITMAP:
					_bmap.bitmapData = null;
					removeChild(_bmap);
					break;
				case EMBED:
					_tf.embedFonts = false;
					removeChild(_tf);
					break;
				case DEVICE:
					_mask = null;
					removeChild(_mask);
					removeChild(_tf);
					break;
			}
			switch (mode) {
				case BITMAP:
					rasterize();
					addChild(_bmap);
					break;
				case EMBED:
					_tf.embedFonts = true;
					addChild(_tf);
					break;
				case DEVICE:
					_mask = new Shape(); drawMask(); _mask.alpha = 0;
					addChild(_tf);
					addChild(_mask);
					break;
			}
			_mode = mode;
		}
		
		public override function render():void
		{
			if (_mode == BITMAP) {
				rasterize();
			} else if (_mode == DEVICE) {
				drawMask();
			}
			layout();
		}
		
		protected function layout():void
		{
			var d:DisplayObject = (_mode==BITMAP ? _bmap : _tf);
			
			// horizontal anchor
			switch (_hAnchor) {
				case CENTER: d.x = -d.width / 2; break;
				case RIGHT:  d.x = -d.width; break;
			}
			// vertical anchor
			switch (_vAnchor) {
				case MIDDLE: d.y = -d.height / 2; break;
				case BOTTOM: d.y = -d.height; break;
			}
		}
		
		protected function drawMask():void
		{
			_mask.graphics.clear();
			var r:Rectangle = _tf.getBounds(this);
			_mask.graphics.beginFill(_maskColor);
			_mask.graphics.drawRect(r.x, r.y, r.width, r.height);
			_mask.graphics.endFill();
		}
		
		protected function rasterize():void
		{
			if (_locked) return;
			var tw:Number = _tf.width;
			var th:Number = _tf.height;
			var bd:BitmapData = _bmap.bitmapData;
			if (bd == null || bd.width != tw || bd.height != th) {
				bd = new BitmapData(tw, th, true, 0x00ffffff);
				_bmap.bitmapData = bd;
			} else {
				bd.fillRect(new Rectangle(0,0,tw,th), 0x00ffffff);
			}
			bd.draw(_tf);
		}
		
		public function setTextFormat(format:TextFormat, beginIndex:int=-1, endIndex:int=-1):void
		{
			_fmt = format;
			_tf.setTextFormat(format, beginIndex, endIndex);
			dirty();
		}
		
		/**
		 * Locks this TextSprite, such that no re-rendering of the text is
		 * performed until the <code>unlock</code> method is called. This
		 * method can be used if a number of sequential updates are to be made.
		 */
		public function lock():void
		{
			_locked = true;
		}
		
		/**
		 * Unlocks this TextSprite, allowing re-rendering to resume if the
		 * sprite has been locked using the <code>lock</code> method.
		 */
		public function unlock():void
		{
			if (_locked) {
				_locked = false;
				if (_mode == BITMAP) rasterize();
			}
		}
	}
}