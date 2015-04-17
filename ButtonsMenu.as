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
		private var pageNav:Sprite = null;			// bottom little squares to page navigate
		private var menuTabs:Sprite = null;

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
			titleTf = Utils.createText(title,15,0x333333,(bw+marg)*c+marg*3);
			titleTf.y = 10;
			var tff:TextFormat = titleTf.defaultTextFormat;
			tff.align = "center";
			titleTf.setTextFormat(tff);
			addChild(titleTf);

			filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];

			menuBtns = new Sprite();		// the menu buttons container
			menuBtns.buttonMode = true;
			menuBtns.mouseChildren = false;
			addChild(menuBtns);
			pageNav = new Sprite();		// the page buttons at the bottom of the page
			addChild(pageNav);

			addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
			addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
			addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
			addEventListener(Event.ENTER_FRAME,onEnterFrame);

			setButtons(Icos);
		}//endfunction

		//===============================================================================================
		// populates this menu with given button icons
		//===============================================================================================
		public function setButtons(Icos:Vector.<Sprite>):void
		{
			if (Icos==null) Icos = new Vector.<Sprite>();
			Btns = Icos;
			var mbw:int=0;
			var mbh:int=0;
			for (var i:int=Icos.length-1; i>-1; i--)
			{
				mbw+=Icos[i].width;
				mbh+=Icos[i].height;
			}
			if (mbw>0)	bw = mbw/Icos.length;
			if (mbh>0)	bh = mbh/Icos.length;
			
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
				sqr.graphics.beginFill(0x666666,1);
				sqr.graphics.drawRect(0,0,9,9);
				sqr.graphics.endFill();
				if (i==idx)
					sqr.graphics.beginFill(0x999999,1);
				else
					sqr.graphics.beginFill(0x777777,1);
				sqr.graphics.drawRect(0,0,9,9);
				sqr.graphics.endFill();
				sqr.x = i*(sqr.width+10);
				sqr.buttonMode = true;
				pageNav.addChild(sqr);
			}
			
			// ----- draws the menu base panel
			this.graphics.clear();
			if (pageCnt>1)
			{
				pageNav.visible=true;
				Utils.drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xEEEEEE,0xEAEAEA,20,10);
				Utils.drawStripedRect(this,3,3,(bw+marg)*c+marg*3-6,(bh+marg)*r+marg*3+marg*2-6,0xFFFFFF,0xFCFCFC,20,10);
			}
			else
			{
				pageNav.visible=false;
				Utils.drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xEEEEEE,0xEAEAEA,20,10);
				Utils.drawStripedRect(this,3,3,(bw+marg)*c+marg*3-6,(bh+marg)*r+marg*3-6,0xFFFFFF,0xFCFCFC,20,10);
			}
			
			// ----- center bottom pageNav buttons
			pageNav.x = (this.width-pageNav.width)/2;
			pageNav.y =this.height-marg*2-pageNav.height/2;

			pageIdx = idx;
		}//endfunction
		
		//===============================================================================================
		// create the tabs at the top of the menu, callback with the selected index
		//===============================================================================================
		public function createTabs(sideLabels:Vector.<String>,callBack:Function):void
		{
			trace("createTabs("+sideLabels+","+callBack+")");
			var Tabs:Sprite = new Sprite();
			
			for (var i:int=0; i<sideLabels.length; i++)
			{
				var btn:Sprite= new Sprite();
				sideLabels[i] = sideLabels[i].split("").join("\n");
				var tf:TextField = Utils.createText(sideLabels[i],13,0x333333);
				tf.x = 5;
				tf.y = 5;
				btn.addChild(tf);
				btn.buttonMode = true;
				btn.mouseChildren = false;
				Tabs.addChild(btn);
			}
			
			var tbTfW:int = Tabs.width;
			function setTabHighlight(idx:int):void
			{
				var offY:int=0;
				for (var i:int=0; i<Tabs.numChildren; i++)
				{
					var btn:Sprite = (Sprite)(Tabs.getChildAt(i));
					var tf:TextField = (TextField)(btn.getChildAt(btn.numChildren-1));
					btn.graphics.clear();
					if (i==idx)
						Utils.drawStripedRect(btn,0,0,tbTfW+10,tf.height+10,0xFFFFFF,0xFCFCFC,10,10);
					else
						Utils.drawStripedRect(btn,0,0,tbTfW+10,tf.height+10,0xEEEEEE,0xEAEAEA,10,10);
					tf.x = 5+(tbTfW-tf.width)/2;
					btn.y = offY;
					offY += btn.height+2;
				}
			}//endfunction
			setTabHighlight(0);
			
			function clickHandler(ev:Event):void
			{
				for (var i:int = 0; i < Tabs.numChildren; i++)
					if (Tabs.getChildAt(i).hitTestPoint(Tabs.stage.mouseX, Tabs.stage.mouseY,true))
					{
						setTabHighlight(i);
						if (callBack!=null) callBack(i);
						return;
					}
			}//endfunction
			
			function removeHandler(ev:Event):void
			{
				Tabs.removeEventListener(MouseEvent.CLICK, clickHandler);
				Tabs.removeEventListener(Event.REMOVED_FROM_STAGE, removeHandler);	
			}//endfunction
			
			Tabs.addEventListener(MouseEvent.CLICK, clickHandler);
			Tabs.addEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
			
			if (menuTabs!=null) menuTabs.parent.removeChild(menuTabs);
			menuTabs = Tabs;
			addChild(menuTabs);
		}//endfunction
		
		//===============================================================================================
		// enable drag or listen to button press
		//===============================================================================================
		protected function onMouseDown(ev:Event):void
		{
			if (stage==null) return;
			trace("mouseDown!!");
			mouseDownPt = new Point(this.parent.mouseX,this.parent.mouseY);
			if (draggable)	menuOffset = new Point(this.x,this.y).subtract(mouseDownPt);
		}//endfunction

		//===============================================================================================
		//
		//===============================================================================================
		protected function onMouseUp(ev:Event):void
		{
			if (stage==null) return;
			if (mouseDownPt==null)	return;	// mousedown somewhere else
			menuOffset = null;
			if (mouseDownPt.subtract(new Point(this.parent.mouseX,this.parent.mouseY)).length>10) return;	// is dragging
			mouseDownPt = null;

			// ----- switch page if page nav button pressed
			for (var i:int=pageNav.numChildren-1; i>-1; i--)
				if (pageNav.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);

			// ----- trigger callback if menu button pressed
			if (Btns!=null)
			{
				for (i=Btns.length-1; i>-1; i--)
				if (Btns[i].parent==menuBtns && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
				{
					trace("Btn "+i+"pressed!");
					if  (callBackFn!=null) callBackFn(i);	// exec callback function
					return;
				}
			}
		}//endfunction

		//===============================================================================================
		// handles buttons/menu drag interractions
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

			if (menuOffset!=null)
			{
				this.x = menuOffset.x+this.parent.mouseX;
				this.y = menuOffset.y+this.parent.mouseY;
			}
			
			if (menuTabs!=null)
			{
				if (x*2+(bw+marg)*c+marg*3 < stage.stageWidth)
					menuTabs.x = (bw+marg)*c+marg*3 + 5;
				else
					menuTabs.x = -menuTabs.width-5;
			}
			
			// ----- ensure menu within stage bounds
			if (this.x+(bw+marg)*c+marg*3>stage.stageWidth)		this.x = stage.stageWidth-(bw+marg)*c-marg*3;
			if (this.y+this.height>stage.stageHeight)			this.y = stage.stageHeight-this.height;
			if (this.x<0)	this.x = 0;
			if (this.y<0)	this.y = 0;
		}//endfunction

		//===============================================================================================
		// to cleanup listeners when removed from stage
		//===============================================================================================
		protected function onRemove(ev:Event):void
		{
			removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
			removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
			removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
			removeEventListener(Event.ENTER_FRAME,onEnterFrame);
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
