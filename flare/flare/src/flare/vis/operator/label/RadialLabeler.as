package flare.vis.operator.label
{
	import flare.display.TextSprite;
	import flare.vis.data.Data;
	import flare.vis.data.DataSprite;
	import flare.vis.util.Shapes;
	
	import flash.text.TextFormat;

	/**
	 * Labeler that orients labels placed on a circle. Labels can be rotated
	 * such that they align radially.
	 */
	public class RadialLabeler extends Labeler
	{
		/** If true, labels will be rotated to align along the radius. */
		public var rotateLabels:Boolean = false;
		
		/** The number of pixels to offset labels along the radius. */
		public var radiusOffset:Number = 0;
		
		/** The number of radians to offset a label's angle. */
		public var angleOffset:Number = 0;
		
		/**
		 * Creates a new RadialLabeler. 
		 * @param source the property from which to retrieve the label text.
		 *  If this value is a string or property instance, the label text will
		 *  be pulled directly from the named property. If this value is a
		 *  Function or Expression instance, the value will be used to set the
		 *  <code>textFunction<code> property and the label text will be
		 *  determined by evaluating that function.
		 * @param rotate flag indicating if labels should be rotated to align
		 *  along the radius. If true, all text sprite labels should use
		 *  embedded fonts to keep the rotated labels legibile. If false,
		 *  labels will instead have their horizontal and vertical anchor
		 *  settings adjusted according to their angle.
		 * @param format optional text formatting information for labels
		 * @param filter a Boolean-valued filter function determining which
		 *  items will be given labels
		 * @param policy the label creation policy. One of LAYER (for adding a
		 *  separate label layer) or CHILD (for adding labels as children of
		 *  data objects)
		 */
		public function RadialLabeler(source:*, rotate:Boolean=false,
			format:TextFormat=null, filter:*=null, policy:String=CHILD)
		{
			super(source, Data.NODES, format, filter, policy);
			this.rotateLabels = rotate;
		}
		
		/** @inheritDoc */
		protected override function process(d:DataSprite):void
		{
			var label:TextSprite = getLabel(d, true);
			var o:Object, r:Number, a:Number, b:Number, v:Boolean;
			
			if (_policy == LAYER) {
				label.origin = d.origin;
				o = _t.$(d);
				if (o.shape == Shapes.WEDGE) {
					a = o.u + o.w/2;
					r = o.h;
				} else {
					r = o.radius;
					a = o.angle;
				}
				b = o.alpha;
				v = o.visible;
				
				o = _t.$(label);
				o.radius = r + radiusOffset;
				o.angle = a + angleOffset;
				o.alpha = b;
				o.visible = v;
			} else {
				a = _t.$(d).angle;
				o = _t.$(label);
				o.radius = radiusOffset;
				o.angle  = a + angleOffset;
			}
			if (rotateLabels) rotate(d);
		}
		
		private function rotate(d:DataSprite):void
		{
			var label:TextSprite = d.props.label as TextSprite;
			if (!label) return;
			
			var a:Number = _t.$(d).angle;
			while (a >  Math.PI) a -= 2*Math.PI;
			while (a < -Math.PI) a += 2*Math.PI;
			
			var o:Object = _t.$(label);
			if (a > -Math.PI/2 && a <= Math.PI/2) {
				o.rotation = -(180/Math.PI) * a;
				o.horizontalAnchor = TextSprite.LEFT;
			} else {
				o.rotation = -(180/Math.PI) * (a + Math.PI);
				o.horizontalAnchor = TextSprite.RIGHT;
			}
		}
		
	} // end of class RadialLabeler
}