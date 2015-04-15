package 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	/**
	 * ...
	 * @author Minjmirage
	 */
	public class Utils
	{
		private static var LoadedAssets:Object = new Object();	// hashtable of the bytes of loaded assets
		
		//===================================================================================
		// 
		//===================================================================================
		public static function createText(txt:String="",fontSize:int=14,fontColor:uint=0x000000,w:int=-1) : TextField
		{
			if (txt == null) txt = "";
			var tf:TextField = new TextField();
			tf.height = 1;
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.selectable = false;
			var tff:TextFormat = tf.defaultTextFormat;
			tff.size = fontSize;
			tff.color = fontColor;
			tf.defaultTextFormat = tff;
			tf.setTextFormat(tff);
			tf.textColor = fontColor;
			tf.htmlText = txt;
			if (w>0)
			{
				var h:int = tf.height+1;
				tf.autoSize = "none";
				tf.width = w;
				tf.height = h;
			}
			
			return tf;
		}//endfunction
		
		//===================================================================================
		// creates a text input textfield enabling input on click 
		//===================================================================================
		public static function createInputText(onTextChange:Function,txt:String="",size:uint=14,c:uint=0x000000,w:int=-1,replaceTxt:Boolean=false) : TextField
		{
			var tf:TextField = createText(txt,size,c,w);
			tf.selectable = true;
			var stageRef:Stage = null;
			tf.addEventListener(FocusEvent.FOCUS_IN,enterEditHandler);
			tf.addEventListener(MouseEvent.CLICK,enterEditHandler);
			tf.addEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
			tf.addEventListener(Event.ADDED_TO_STAGE, addToStageHandler);
			
			function enterEditHandler(ev:Event):void
			{
				trace("enterEditClick");
				tf.removeEventListener(MouseEvent.CLICK,enterEditHandler);
				tf.type = "input";
				if (replaceTxt) tf.text = "";
				else 			tf.border = true;
				tf.addEventListener(KeyboardEvent.KEY_DOWN,exitEditHandler);
				stageRef.addEventListener(MouseEvent.MOUSE_DOWN,exitEditHandler);
			}//endfunction
			
			function exitEditHandler(ev:Event):void
			{
				trace("exitEditClick");
				if(ev is MouseEvent && !tf.hitTestPoint(stageRef.mouseX,stageRef.mouseY) ||	// clicked elsewhere
				   (ev is KeyboardEvent && (ev as KeyboardEvent).charCode==13))			// key is ENTER
				{
					tf.removeEventListener(KeyboardEvent.KEY_DOWN,exitEditHandler);
					stageRef.removeEventListener(MouseEvent.MOUSE_DOWN,exitEditHandler);
					tf.addEventListener(MouseEvent.CLICK,enterEditHandler);
					tf.border = false;
					tf.type = "dynamic";
					if (onTextChange!=null) onTextChange(tf.text);
				}
			}//endfunction
			
			function addToStageHandler(ev:Event):void
			{
				trace("input Tf added to stage");
				stageRef = tf.stage;
				tf.removeEventListener(Event.ADDED_TO_STAGE, addToStageHandler);
			}
			
			function removeHandler(ev:Event):void
			{
				tf.removeEventListener(FocusEvent.FOCUS_IN,enterEditHandler);
				tf.removeEventListener(MouseEvent.CLICK,enterEditHandler);
				stageRef.removeEventListener(MouseEvent.MOUSE_DOWN,exitEditHandler);
				tf.removeEventListener(KeyboardEvent.KEY_DOWN,exitEditHandler);
				tf.removeEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
				tf.removeEventListener(Event.ADDED_TO_STAGE, addToStageHandler);
			}//endfunction
			
			return tf;
		}//endfunction

		//===================================================================================
		// to pretty print JSON data
		//===================================================================================
		public static function prnObject(o:Object,nest:int=0):String
		{
			var tabs:String="";
			for (var i:int=0; i<nest; i++)
				tabs+="  ";
				
			var s:String = "{";
			for(var id:String in o) 
			{
				var value:Object = o[id];
				if (value is String || value is int || value is Number || value is Boolean)
					s += "\n"+tabs+"  "+id+"="+value;
				else
					s += "\n"+tabs+"  "+id+"="+prnObject(value,nest+1);
			}
			return s+"}";
		}//endfunction
		
		//=============================================================================
		// convenience function to load JSON from server
		//=============================================================================
		public static function loadJson(url:String, callBack:Function):void
		{
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(url);
			ldr.load(req);
			ldr.addEventListener(Event.COMPLETE, onComplete);  
			function onComplete(e:Event):void
			{
				ldr.removeEventListener(Event.COMPLETE, onComplete);  
				callBack(JSON.parse(ldr.data));
			}//
		}//endfunction
		
		//===================================================================================
		// function to load image assets from url or reinstantiate from loaded bytes
		//===================================================================================
		public static function loadAsset(url:String,callBack:Function):void
		{
			url = url.split("//").join("/").split(":/").join("://");
			
			var ldr:Loader = null;
			
			if (LoadedAssets[url]!=null)
			{
				ldr = new Loader();
				ldr.contentLoaderInfo.addEventListener(Event.COMPLETE,function(ev:Event):void 
				{
					trace("loadAssets -> loadBytes -> ldr.content = "+ldr.content);
					callBack(ldr.content);
				});
				ldr.loadBytes(LoadedAssets[url]);
			}
			else
			{
				trace("loading asset " + url);
				ldr = new Loader();
				ldr.load(new URLRequest(url));
				function imgLoaded(ev:Event):void
				{
					ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, imgLoaded);
					ldr.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, imgLoaded);
					if (ev is IOErrorEvent)
					{
						trace("Load IOError! "+ev);
						callBack(new Bitmap(new BitmapData(90,90,false,0xFF0000)));
					}
					else
					{
						LoadedAssets[url] = ldr.contentLoaderInfo.bytes;	// stores teh laoded bytes
						callBack(ldr.content);
					}
				}
				ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, imgLoaded);
				ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, imgLoaded);
			}
		}//endfunction
	
		//===============================================================================================
		// draws a striped rectangle in given sprite 
		//===============================================================================================
		public static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
		{
			if (s==null)	s = new Sprite();
			var mat:Matrix = new Matrix();
			mat.createGradientBox(sw,sw,rot,0,0);
			s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
			s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
			s.graphics.endFill();
			
			return s;
		}//endfunction 
		
	}//endclass
}//endpackage