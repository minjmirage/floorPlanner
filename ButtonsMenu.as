package 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	/**
	 * generic menu class
	 * @author Minjmirage
	 */
	public class ButtonsMenu extends Sprite
	{
		public var draggable:Boolean = true;
		
		protected var Btns:Vector.<Sprite> = null;	// list of all buttons
		protected var callBackFn:Function = null;	// callbacks, returning the index of the button clicked
		protected var mouseDownPt:Point = null;
		protected var menuOffset:Point = null;
		
		private var pageIdx:int=0;					// current page
		
		private var titleTf:TextField = null;		// menu title at the top
		private var menuBtns:Sprite = null;			// container for all the menu buttons proper
		private var pageNav:Sprite = null;
		
		private var r:int = 1;		// rows
		private var c:int = 1;		// cols
		private var bw:int = 70;	// btn width
		private var bh:int = 70;	// btn height
		private var marg:int = 10;
	
		//===============================================================================================
		// simpleton constructor, subclasses must initialize Btns and callBackFn
		//===============================================================================================
		public function ButtonsMenu(title:String,Icos:Vector.<Sprite>,callBack:Function,rows:int=3,cols:int=2):void
		{
			callBackFn = callBack;
			
			if (rows<1)	rows = 1;
			if (cols<1) cols = 1;
			r = rows;
			c = cols;
			
			// ----- create the top title
			titleTf = Utils.createText(title,15,0x000000,(bw+marg)*c+marg*3);
			titleTf.y = 10;
			var tff:TextFormat = titleTf.defaultTextFormat;
			tff.align = "center";
			titleTf.setTextFormat(tff);
			addChild(titleTf);
			
			filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
			
			menuBtns = new Sprite();		// the menu buttons container
			addChild(menuBtns);				
			pageNav = new Sprite();		// the page buttons at the bottom of the page
			addChild(pageNav);
			
			addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
			addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
			addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
			addEventListener(Event.ENTER_FRAME,onEnterFrame);
			addEventListener(MouseEvent.MOUSE_OUT,onMouseUp);
			
			setButtons(Icos);
		}//endfunction
		
		//===============================================================================================
		// populates this menu with given button icons
		//===============================================================================================
		public function setButtons(Icos:Vector.<Sprite>):void
		{
			if (Icos==null) Icos = new Vector.<Sprite>();
			Btns = Icos;
			pageTo(0);
		}//endfunction
		
		//===============================================================================================
		// go to page number
		//===============================================================================================
		public function pageTo(idx:int):void
		{
			if (idx<0)	idx = 0;
			if (idx>Math.ceil(Btns.length/(r*c)))	idx = Math.ceil(Btns.length/(r*c));
			
			// ----- show the correct menuButtons
			while (menuBtns.numChildren>0)	menuBtns.removeChildAt(0);	// child 0 is pageNav
			menuBtns.x = marg*2;
			menuBtns.y = marg+titleTf.height;
			var a:int = idx*r*c;
			var b:int = Math.min(Btns.length,a+r*c);
			for (var i:int=a; i<b; i++)
			{
				var btn:Sprite = Btns[i];
				btn.x = (i%c)*(bw+marg)+(bw-btn.width)/2;
				btn.y = int((i-a)/c)*(bh+marg)+(bh-btn.height)/2;
				menuBtns.addChild(btn);
			}
			
			// ----- update pageNav to show correct pages
			var pageCnt:int = Math.ceil(Btns.length/(r*c));
			while (pageNav.numChildren>pageCnt)	
				pageNav.removeChildAt(0);
			for (i=0; i<pageCnt; i++)
			{
				var sqr:Sprite = new Sprite();
				if (i==idx)
					sqr.graphics.beginFill(0x888888,1);
				else 
					sqr.graphics.beginFill(0x666666,1);
				sqr.graphics.drawRect(0,0,9,9);
				sqr.graphics.endFill();
				sqr.x = i*(sqr.width+10);
				sqr.buttonMode = true;
				pageNav.addChild(sqr);
			}
			
			if (pageCnt>1)
			{
				pageNav.visible=true;
				Utils.drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xFFFFFF,0xF6F6F6,20,10);
			}
			else
			{
				pageNav.visible=false;
				Utils.drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xFFFFFF,0xF6F6F6,20,10);
			}
			pageNav.x = (this.width-pageNav.width)/2;
			pageNav.y =this.height-marg*2-pageNav.height/2;
			
			pageIdx = idx;
		}//endfunction	
		
		//===============================================================================================
		// enable drag or listen to button press
		//===============================================================================================
		protected function onMouseDown(ev:Event):void
		{
			if (stage==null) return;
			trace("mouseDown!!");
			mouseDownPt = new Point(this.mouseX,this.mouseY);
			if (draggable)	this.startDrag();
		}//endfunction
		
		//===============================================================================================
		// 
		//===============================================================================================
		protected function onMouseUp(ev:Event):void
		{
			if (stage==null) return;
			this.stopDrag();
			if (mouseDownPt==null)	return;	// mousedown somewhere else
			if (mouseDownPt.subtract(new Point(this.mouseX,this.mouseY)).length>10) return;	// is dragging
			mouseDownPt = null;
			
			// ----- switch page if page nav button pressed
			for (var i:int=pageNav.numChildren-1; i>-1; i--)
				if (pageNav.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);
			
			// ----- trigger callback if menu button pressed
			if (Btns!=null)
			{
				for (i=Btns.length-1; i>-1; i--)
				if (Btns[i].parent==this && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
				{
					trace("Btn "+i+"pressed!");
					if  (callBackFn!=null) callBackFn(i);	// exec callback function
					return;
				}
			}
		}//endfunction
		
		//===============================================================================================
		// handles buttons interractions
		//===============================================================================================
		protected function onEnterFrame(ev:Event):void
		{
			if (stage==null) return;
			
			var A:Array = null;
			
			if (Btns!=null)
			for (var i:int=Btns.length-1; i>-1; i--)
				if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
				{
					A = Btns[i].filters;
					if (A.length==0)
						Btns[i].filters=[new GlowFilter(0x000000,1,4,4,1)];
					else if ((GlowFilter)(A[0]).strength<1)
						(GlowFilter)(A[0]).strength+=0.1;
				}
				else
				{
					if (Btns[i].filters.length>0)
					{
						A = Btns[i].filters;
						if (A.length>0 && (GlowFilter)(A[0]).strength>0)
							(GlowFilter)(A[0]).strength-=0.1;
						else 
							A = null;
						Btns[i].filters = A;
					}
				}
			
			// ----- ensure menu within stage bounds
			if (this.x+this.width>this.stage.stageWidth)	this.x = this.stage.stageWidth-this.width;
			if (this.y+this.height>this.stage.stageHeight)	this.y = this.stage.stageHeight-this.height;
			if (this.x<0)	this.x = 0;
			if (this.y<0)	this.y = 0;
		}//endfunction
		
		//===============================================================================================
		// 
		//===============================================================================================
		protected function onRemove(ev:Event):void
		{
			removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
			removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
			removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
			removeEventListener(Event.ENTER_FRAME,onEnterFrame);
			removeEventListener(MouseEvent.MOUSE_OUT,onMouseUp);
		}//endfunction
		
		//===============================================================================================
		// convenience function to make a button to expected dimensions of this menu
		//===============================================================================================
		public function createPicBtn(picUrl:String,txt:String):Sprite
		{
			var s:Sprite = new Sprite();
			
			var tf:TextField = Utils.createText(txt,12,0x000000,bw);
			var bmp:Bitmap = new Bitmap(new BitmapData(bw,bh-tf.height,false,0x999999));
			tf.y = bmp.height;
			s.addChild(tf);
			s.addChild(bmp);
			
			Utils.loadAsset(picUrl,function (pic:DisplayObject):void
			{
				if (pic!=null)
				{
					var bw:int = bmp.bitmapData.width;
					var bh:int = bmp.bitmapData.height;
					var sc:Number = Math.min(bw/pic.width,bh/pic.height);
					bmp.bitmapData.draw(pic,new Matrix(sc,0,0,sc,(bw-pic.width*sc)/2,(bh-pic.height*sc)/2));
				}
			});
			
			return s;
		}//endfunction
		
	}//endclass
}//endpackage