package flare.util
{
	import flare.display.DirtySprite;
	
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	/**
	 * Utility class providing methods for working with display objects.
	 */
	public class Displays
	{
		/**
		 * Constructor, throws an error if called, as this is an abstract class.
		 */
		public function Displays()
		{
			throw new Error("This is an abstract class.");
		}
		
		/**
		 * Adds a listener to the stage via a given display object. If the
		 * display object has already been added to the stage, the listener
		 * will be added to the stage immediately. Otherwise, the listener will
		 * be added whenever the display object is added to the stage. This
		 * method allows you to add listeners for stage events without having
		 * to explicitly manage the case where the defining elements have not
		 * yet been added to the stage.
		 * @param d the display object through which to access the stage
		 * @param eventType the event type
		 * @param listener the event listener
		 * @param useCapture the event useCapture flag
		 * @param priority the event listener priority
		 * @param useWeakReference the event useWeakReference flag
		 * @see flash.events.Event
		 */
		public static function addStageListener(d:DisplayObject,
			eventType:String, listener:Function, useCapture:Boolean=false,
			priority:Number=0, useWeakReference:Boolean=false):void
		{
			if (d.stage) {
				d.stage.addEventListener(eventType, listener, useCapture,
					priority, useWeakReference);
			} else {
				var add:Function = function(e:Event=null):void
				{
					d.stage.addEventListener(eventType, listener,
						useCapture, priority, useWeakReference);
					d.removeEventListener(Event.ADDED_TO_STAGE, add);
					d.stage.invalidate();
				}
				d.addEventListener(Event.ADDED_TO_STAGE, add);
			}
		}
		
		/**
		 * Creates a thumbnail image of the input object using the (optional)
		 * given size.  If no width, height, or bitmap data parameters are
		 * provided then the natural size of the display object will be used.
		 * If no width or height values are provided (i.e., they are less than
		 * or equal to zero) but a bitmap data is provided, than the dimensions
		 * of the bitmap data will be used. If all parameters are provided but
		 * the width and height exceed the size of the bitmap data, then the
		 * object will be drawn to match the provided width and height, but the
		 * thumbnail will be clipped to the size of the bitmap data. If only
		 * one of the width or height values are provided, than the other will
		 * automatically be selected to preserve the original aspect ratio of
		 * the object.
		 * @param src the DisplayObject to create a thumbnail image of
		 * @param width the desired width of the object in the thumbnail. If
		 *  this value is less than or equal to zero it is ignored.
		 * @param height the desired height of the object in the thumbnail If
		 *  this value is less than or equal to zero it is ignored.
		 * @param bd a BitmapData instance into which to draw the thumbnail.
		 *  If no value is provided, a new BitmapData instance of the needed
		 *  width and height will automatically be created.
		 * @return the thumbnail image as a BitmapData instance
		 */
		public static function thumbnail(src:DisplayObject, width:Number=-1,
			height:Number=-1, bd:BitmapData=null):BitmapData
		{
			DirtySprite.renderDirty(); // make sure everything is rendered
			
			var r:Rectangle = src.getBounds(src);
			var hasW:Boolean = width>0, hasH:Boolean = height>0;
			
			// get thumbnail dimensions
			if (hasW && !hasH) {
				height = r.height * width / r.width;
			} else if (!hasW && hasH) {
				width = r.width * height / r.height;
			} else {
				width  = hasW ? width  : (bd ? bd.width  : r.width);
				height = hasH ? height : (bd ? bd.height : r.height);
			}
			// create bitmap data as needed
			bd = bd ? bd : new BitmapData(width, height);
			
			// determine object transformation
			var mat:Matrix = new Matrix();
			mat.translate(-r.left, -r.top);
			mat.scale(width/r.width, height/r.height);
			
			// draw the thumbnail and return
			bd.draw(src, mat, src.transform.concatenatedColorTransform, src.blendMode);
			return bd;
		}

	} // end of class Displays
}