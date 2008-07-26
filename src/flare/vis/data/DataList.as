package flare.vis.data
{
	import flare.animate.Transitioner;
	import flare.util.Arrays;
	import flare.util.Filter;
	import flare.util.IEvaluable;
	import flare.util.Property;
	import flare.util.Sort;
	import flare.util.Stats;
	import flare.vis.events.DataEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.flash_proxy;
	import flash.utils.Dictionary;
	import flash.utils.Proxy;

	[Event(name="add",    type="flare.vis.events.DataEvent")]
	[Event(name="remove", type="flare.vis.events.DataEvent")]

	/**
	 * A list of nodes or edges maintained by a Data instance. Items contained
	 * in this list can be accessed using array notation (<code>[]</code>),
	 * iterated over using the <code>for each</code> construct, or can be
	 * processed by passing a visitor function to the <code>visit</code>
	 * method.
	 * 
	 * <p>Data lists also support listeners for add and remove events. These
	 * events are fired <em>before</em> the add or remove is executed. These
	 * data events can be canceled by calling <code>preventDefault()</code>
	 * on the <code>DataEvent</code> object, thereby preventing the add or
	 * remove from being performed. Using this mechanism, clients can add
	 * custom constraints on the contents of a data list by adding new
	 * listeners that monitor add and remove events and cancel them when
	 * desired.</p>
	 */
	public class DataList extends Proxy implements IEventDispatcher
	{
		private var _dispatch:EventDispatcher = new EventDispatcher();
		
		/** Hashed set of items in the data list. */
		private var _map:Dictionary = new Dictionary();
		/** Array of items in the data set. */
		private var _list:Array = [];
		/** Default property values to be applied to new items. */
		private var _defs:Object = null;
		/** Cache of Stats objects for item properties. */
		private var _stats:Object = {};
		/** The underlying array storing the list. */
		internal function get list():Array { return _list; }
		
		/** The name of this data list. */
		public function get name():String { return _name; }
		private var _name:String;
		
		/** Internal count of visitors traversing the current list. */
		private var _visiting:int = 0;
		private var _sort:Sort;
		
		/** The number of items contained in this list. */
		public function get length():int { return _list.length; }
		
		/** A standing sort criteria for items in the list. */
		public function get sort():Sort { return _sort; }
		public function set sort(s:*):void {
			_sort = s==null ? s : (s is Sort ? Sort(s) : new Sort(s));
			if (_sort != null) _sort.sort(_list);
		}
		
		// --------------------------------------------------------------------
		
		/**
		 * Creates a new DataList instance. 
		 * @param editable indicates if this list should be publicly editable.
		 */
		public function DataList(name:String) {
			_name = name;
		}
		
		// -- Basic Operations: Contains, Add, Remove, Clear ------------------
		
		/**
		 * Indicates if the given object is contained in this list.
		 * @param d the object to check for containment
		 * @return true if the list contains the object, false otherwise.
		 */
		public function contains(d:DataSprite):Boolean
		{
			return (_map[d] != undefined);
		}
		
		/**
		 * Add a DataSprite to the list.
		 * @param d the DataSprite to add
		 * @return the added DataSprite, or null if the add failed
		 */
		public function add(d:DataSprite):DataSprite
		{
			if (!fireEvent(DataEvent.ADD, d))
				return null;
			
			_map[d] = _list.length;
			_stats = {};
			if (_sort != null) {
				var idx:int = Arrays.binarySearch(_list, d, null,
				                                  _sort.comparator);
				_list.splice(-(idx+1), 0, d);
			} else {
				_list.push(d);
			}
			return d;
		}
		
		/**
		 * Remove a data sprite from the list.
		 * @param ds the DataSprite to remove
		 * @return true if the object was found and removed, false otherwise
		 */
		public function remove(d:DataSprite):Boolean
		{
			if (_map[d] == undefined) return false;
			if (!fireEvent(DataEvent.REMOVE, d))
				return false;
			if (_visiting > 0) {
				// if called from a visitor, use a copy-on-write strategy
				_list = Arrays.copy(_list);
				_visiting = 0; // reset the visitor count
			}
			Arrays.remove(_list, d);
			delete _map[d];
			_stats = {};	
			return true;
		}
		
		/**
		 * Remove a DataSprite from the list.
		 * @param idx the index of the DataSprite to remove
		 * @return the removed DataSprite
		 */
		public function removeAt(idx:int):DataSprite
		{
			var d:DataSprite = _list[idx];
			if (d == null || !fireEvent(DataEvent.REMOVE, d))
				return null;
			
			Arrays.removeAt(_list, idx);
			if (d != null) {
				delete _map[d];
				_stats = {};
			}
			return d;
		}
		
		/**
		 * Remove all DataSprites from this list.
		 */
		public function clear():Boolean
		{
			if (_list.length == 0) return true;
			if (!fireEvent(DataEvent.REMOVE, _list))
				return false;
			_map = new Dictionary();
			_list = [];
			_stats = {};
			return true;
		}
		
		/**
		 * Returns an array of data objects for each item in this data list.
		 * Data objects are retrieved from the "data" property for each item.
		 * @return an array of data objects for items in this data list
		 */
		public function toDataArray():Array
		{
			var a:Array = new Array(_list.length);
			for (var i:int=0; i<a.length; ++i) {
				a[i] = _list[i].data;
			}
			return a;
		}				
		

		// -- Sort ------------------------------------------------------------
		
		/**
		 * Sort DataSprites according to their properties. This method performs
		 * a one-time sorting. To establish a consistent sort order robust over
		 * the addition of new items, use the <code>sort</code> property.
		 * @param args the sort arguments.
		 * 	If a String is provided, the data will be sorted in ascending order
		 *   according to the data field named by the string.
		 *  If an Array is provided, the data will be sorted according to the
		 *   fields in the array. In addition, field names can optionally
		 *   be followed by a boolean value. If true, the data is sorted in
		 *   ascending order (the default). If false, the data is sorted in
		 *   descending order.
		 */
		public function sortBy(...args):void
		{
			if (args.length == 0) return;
			if (args[0] is Array) args = args[0];
			
			var f:Function = Sort.$(args);
			_list.sort(f);
		}

		// -- Visitation ------------------------------------------------------
		
		/**
		 * Iterates over the contents of the list, invoking a visitor function
		 * on each element of the list. If the visitor function returns a
		 * Boolean true value, the iteration will stop with an early exit.
		 * @param visitor the visitor function to be invoked on each item
		 * @param reverse optional flag indicating if the list should be
		 *  visited in reverse order
		 * @param filter an optional boolean-valued function indicating which
		 *  items should be visited
		 * @return true if the visitation was interrupted with an early exit
		 */		
		public function visit(visitor:Function, reverse:Boolean=false,
			filter:*=null):Boolean
		{
			_visiting++; // mark a visit in process
			var a:Array = _list; // use our own reference to the list
			var i:uint, b:Boolean = false;
			var f:Function = Filter.$(filter);
			
			if (reverse && f==null) {
				for (i=a.length; --i>=0;)
					if (visitor(a[i]) as Boolean) {
						b = true; break;
					}
			}
			else if (reverse) {
				for (i=a.length; --i>=0;)
					if (f(a[i]) && (visitor(a[i]) as Boolean)) {
						b = true; break;
					}
			}
			else if (f==null) {
				for (i=0; i<a.length; ++i)
					if (visitor(a[i]) as Boolean) {
						b = true; break;
					}
			}
			else {
				for (i=0; i<a.length; ++i)
					if (f(a[i]) && (visitor(a[i]) as Boolean)) {
						b = true; break;
					}
			}
			_visiting = Math.max(0, --_visiting); // unmark a visit in process
			return b;
		}
		
		// -- Default Values --------------------------------------------------
		
		/**
		 * Sets a default property value for newly created items.
		 * @param name the name of the property
		 * @param value the value of the property
		 */
		public function setDefault(name:String, value:*):void
		{
			if (_defs == null) _defs = {};
			_defs[name] = value;
		}
		
		/**
		 * Removes a default value for newly created items.
		 * @param name the name of the property
		 */
		public function removeDefault(name:String):void
		{
			if (_defs != null) delete _defs[name];
		}
		
		/**
		 * Sets default values for newly created items.
		 * @param values the default properties to set
		 */
		public function setDefaults(values:Object):void
		{
			if (_defs == null) _defs = {};
			for (var name:String in values)
				_defs[name] = values[name];
		}
		
		/**
		 * Clears all default value settings for this list.
		 */
		public function clearDefaults():void
		{
			_defs = null;
		}
		
		/**
		 * Applies the default values to an object.
		 * @param o the object on which to set the default values
		 * @param vals the set of default property values
		 */
		public function applyDefaults(o:Object):void
		{
			if (_defs == null) return;
			
			for (var name:String in _defs) {
				var value:* = _defs[name];
				if (value is IEvaluable) {
					value = IEvaluable(value).eval(o);
				} else if (value is Function) {
					value = (value as Function)(o);
				}
				Property.$(name).setValue(o, value);
			}
		}
		
		// -- Set Values ------------------------------------------------------
		
		/**
		 * Sets a property value on all items in the list.
		 * @param name the name of the property
		 * @param value the value of the property
		 * @param t a transitioner or time span for updating object values. If
		 *  the input is a transitioner, it will be used to store the updated
		 *  values. If the input is a number, a new Transitioner with duration
		 *  set to the input value will be used. The input is null by default,
		 *  in which case object values are updated immediately.
		 * @param filter an optional Boolean-valued filter function for
		 * 	limiting which items are visited
		 * @return the transitioner used to update the values
		 */
		public function setProperty(name:String, value:*, t:*=null,
			filter:*=null):Transitioner
		{
			var o:Object;
			var trans:Transitioner = Transitioner.instance(t);
			var f:Function = Filter.$(filter);
			var v:Function = value is Function ? value as Function
				 : value is IEvaluable ? IEvaluable(value).eval : null;
			
			if (v != null) {
				for each (o in _list) if (f==null || f(o))
					trans.setValue(o, name, v(trans.$(o)));
			} else {
				for each (o in _list) if (f==null || f(o))
					trans.setValue(o, name, value);
			}
			return trans;
		}
		
		/**
		 * Sets property values on all sprites in a given group.
		 * @param vals an object containing the properties and values to set.
		 * @param t a transitioner or time span for updating object values. If
		 *  the input is a transitioner, it will be used to store the updated
		 *  values. If the input is a number, a new Transitioner with duration
		 *  set to the input value will be used. The input is null by default,
		 *  in which case object values are updated immediately.
		 * @param filter an optional Boolean-valued filter function for
		 * 	limiting which items are visited
		 * @return the transitioner used to update the values
		 */
		public function setProperties(vals:Object, t:*=null,
			filter:*=null):Transitioner
		{
			var o:Object;
			var trans:Transitioner = Transitioner.instance(t);
			var f:Function = Filter.$(filter);
			
			for (var name:String in vals) {
				var value:* = vals[name];
				var v:Function = value is Function ? value as Function
					 : value is IEvaluable ? IEvaluable(value).eval : null;
				
				if (v != null) {
					for each (o in _list) if (f==null || f(o))
						trans.setValue(o, name, v(trans.$(o)));
				} else {
					for each (o in _list) if (f==null || f(o))
						trans.setValue(o, name, value);
				}
			}
			return trans;
		}
		
		/**
		 * A function generator that can be used to set properties
		 * at a later time. This method returns a function that can
		 * accept a <code>Transitioner</code> as its sole argument and then
		 * executes the <code>setProperties</code> method. 
		 * @param vals an object containing the properties and values to set.
		 * @param filter an optional Boolean-valued filter function for
		 * 	limiting which items are visited
		 * @return a function that accepts a <code>Transitioner</code> argument
		 *  and runs <code>setProperties</code>.
		 */
		public function setLater(vals:Object, filter:*=null):Function
		{
			return function(t:Transitioner=null):Transitioner {
				return setProperties(vals, t, filter);
			}
		}
		
		
		// -- Statistics ------------------------------------------------------
				
		/**
		 * Computes and caches statistics for a data field. The resulting
		 * <code>Stats</code> object is cached, so that later access does not
		 * require any re-calculation. The cache of statistics objects may be
		 * cleared, however, if changes to the data set are made.
		 * @param field the property name
		 * @return a <code>Stats</code> object with the computed statistics
		 */
		public function stats(field:String):Stats
		{
			// TODO: allow custom comparators?
			
			// check cache for stats
			if (_stats[field] != undefined) {
				return _stats[field] as Stats;
			} else {
				return _stats[field] = new Stats(_list, field);
			}
		}
		
		
		/**
		 * Clears any cached stats for the given field. 
		 * @param field the data field to clear the stats for.
		 */
		public function clearStats(field:String):void
		{
			delete _stats[field];
		}
		
		
		// -- Event Dispatcher Methods ----------------------------------------
		
		/** @private */
		protected function fireEvent(type:String, items:*):Boolean
		{
			if (_dispatch.hasEventListener(type)) {
				return _dispatch.dispatchEvent(
					new DataEvent(type, items, this));
			}
			return true;
		}
		
		/** @inheritDoc */
		public function addEventListener(type:String, listener:Function,
			useCapture:Boolean=false, priority:int=0, 
			useWeakReference:Boolean=false) : void
		{
			_dispatch.addEventListener(type, listener, useCapture, priority,
				useWeakReference);
		}
		
		/** @inheritDoc */
		public function dispatchEvent(event:Event):Boolean
		{
			return _dispatch.dispatchEvent(event);
		}
		
		/** @inheritDoc */
		public function hasEventListener(type:String):Boolean
		{
			return _dispatch.hasEventListener(type);
		}
		
		/** @inheritDoc */
		public function removeEventListener(type:String, listener:Function,
			useCapture:Boolean=false):void
		{
			_dispatch.removeEventListener(type, listener, useCapture);
		}
		
		/** @inheritDoc */
		public function willTrigger(type:String):Boolean
		{
			return _dispatch.willTrigger(type);
		}
		
		// -- Proxy Methods ---------------------------------------------------
		
		/** @private */
		flash_proxy override function getProperty(name:*):*
		{
        	return _list[name];
    	}
    	
    	/** @private */
    	flash_proxy override function setProperty(name:*, value:*):void
    	{
    		this.setProperty(name, value);
    	}
		
		/** @private */
		flash_proxy override function nextNameIndex(idx:int):int
		{
			return (idx < _list.length ? idx + 1 : 0);
		}

		/** @private */
		flash_proxy override function nextName(idx:int):String
		{
			return String(idx-1);
		}
		
		/** @private */
		flash_proxy override function nextValue(idx:int):*
		{
			return _list[idx-1];
		}
		
	} // end of class DataList
}