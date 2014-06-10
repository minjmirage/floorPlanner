package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Vector3D;
	import flash.utils.getTimer;
	import flash.text.TextField;
	
	[SWF(width = "800", height = "600", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * @author mj
	 */
	public class FloorPlanner extends Sprite 
	{
		private var mouseDownPt:Vector3D = null;
		private var mouseUpPt:Vector3D= null;
		private var gridBg:Sprite = null;
		private var floorPlanBg:Sprite = null;
		private var floorPlan:FloorPlan = null;
		
		private var stepFn:Function = null;
		private var mouseDownFn:Function = null;
		private var mouseUpFn:Function = null;
		
		private var titleTf:TextField = null;
		private var debugTf:TextField = null;
		
		private var mode:int=0;
		
		//=============================================================================================
		//
		//=============================================================================================
		public function FloorPlanner():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}//
		
		//=============================================================================================
		// Entry point
		//=============================================================================================
		private function init(e:Event=null):void 
		{
			stage.scaleMode = "noScale";
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			debugTf = new TextField();
			debugTf.width = stage.stageWidth;
			debugTf.height = stage.stageHeight;
			debugTf.mouseEnabled = false;
			debugTf.text = "stage: "+stage.stageWidth+"x"+stage.stageHeight;
			stage.addChild(debugTf);
			
			mouseDownPt = new Vector3D();
			mouseUpPt = new Vector3D();
			floorPlan = new FloorPlan();
			
			// ----- add grid background
			gridBg = new WireGrid(stage.stageWidth,stage.stageHeight);
			stage.addChild(gridBg);
			
			// ----- drawing sprite
			floorPlanBg = new Sprite();
			stage.addChild(floorPlanBg);
			
			var menu:Sprite = new ButtonsMenu("OPERATIONS",
												Vector.<String>(["ADD WALLS","ADD DOORS","ADD WINDOWS","ADD FURNITURE"]),
												Vector.<Function>([function():void {},function():void {},function():void {}]));
			stage.addChild(menu);
			
			// ----- title
			titleTf = new TextField();
			titleTf.autoSize = "left";
			titleTf.wordWrap = false;
			titleTf.text = "EDIT MODE";
			stage.addChild(titleTf);
						
			// ----- add controls
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}//endfunction
				
		//=============================================================================================
		// defacto mode
		//=============================================================================================
		private function editMode():void
		{
			var lastJoint:Vector3D = null;
			stepFn = function():void
			{
				if (lastJoint!=null)
				{
					lastJoint.x = gridBg.mouseX;
					lastJoint.y = gridBg.mouseY;
				}
			}
			mouseDownFn = function():void
			{
				lastJoint = floorPlan.nearestJoint(mouseDownPt,10);		// chk if near any joint
			}
			mouseUpFn = function():void
			{
				lastJoint = null;
			}
		}//endfunction
		
		//=============================================================================================
		// create walls step
		//=============================================================================================
		private function addWallsMode(snapDist:Number=10):void
		{
			var wall:Wall = null;
			
			stepFn = function():void
			{
				if (wall!=null)
				{
					wall.joint2.x = gridBg.mouseX;
					wall.joint2.y = gridBg.mouseY;
				}
			}
			mouseDownFn = function():void
			{
				if (wall==null)
					wall = floorPlan.createWall(new Vector3D(gridBg.mouseX,gridBg.mouseY),
												new Vector3D(gridBg.mouseX,gridBg.mouseY),
												10);
			}
			mouseUpFn = function():void
			{
				if (wall!=null && wall.joint1.subtract(wall.joint2).length<=snapDist)
					floorPlan.removeWall(wall);
				wall = null;
			}
		}//endfunction
		
		//=============================================================================================
		// Main Loop
		//=============================================================================================
		private function onEnterFrame(ev:Event):void
		{
			if (stepFn!=null) stepFn();
			titleTf.x = (800-titleTf.width)/2;
			titleTf.y = (600*0.1);
			floorPlan.draw(floorPlanBg);		// update floor plan drawings
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseDown(ev:Event):void
		{
			if (getTimer()-mouseDownPt.w<300)
			{
				if (mode==0)	{mode=1; titleTf.text="Adding Walls"; addWallsMode();}
				else			{mode=0; titleTf.text="Editing Walls"; editMode();}
			}
			if (mouseDownFn!=null) mouseDownFn();
			mouseDownPt = new Vector3D(gridBg.mouseX,gridBg.mouseY,0,getTimer());
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseUp(ev:Event):void
		{
			if (mouseUpFn!=null) mouseUpFn();
			mouseUpPt = new Vector3D(gridBg.mouseX,gridBg.mouseY,0,getTimer());
		}//endfunction
		
		
	}//endclass
}//endpackage

import flash.display.DisplayObject;
import flash.geom.Vector3D;
import flash.geom.Point;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.GlowFilter;
import flash.filters.DropShadowFilter;
import flash.text.TextFormat;


class ButtonsMenu extends Sprite
{
	private var Btns:Vector.<Sprite> = null;
	private var Fns:Vector.<Function> = null;
	private var titleTf:TextField = null;

	public function ButtonsMenu(title:String,labels:Vector.<String>,callBacks:Vector.<Function>):void
	{
		Fns = callBacks;
		
		// ----- create title
		titleTf = new TextField();
		var tff:TextFormat = titleTf.defaultTextFormat;
		tff.font = "arial";
		tff.bold = true;
		tff.size = 20;
		tff.align = "center";
		titleTf.defaultTextFormat = tff;
		titleTf.text = title;
		titleTf.autoSize = "left";
		titleTf.wordWrap = false;
		addChild(titleTf);
		
		// ----- create buttons
		tff.size = 15;
		Btns = new Vector.<Sprite>();
		var n:int = Math.min(labels.length,callBacks.length);
		for (var i:int=0; i<n; i++)
		{
			var b:Sprite = new Sprite();
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.defaultTextFormat = tff;
			tf.text = labels[i];
			b.addChild(tf);
			b.buttonMode = true;
			b.mouseChildren = false;
			Btns.push(b);
			addChild(b);
		}
		
		// ----- aligning
		var w:int = this.width;
		for (i=0; i<Btns.length; i++)
		{
			Btns[i].graphics.beginFill(0xEEEEEE,1);
			Btns[i].graphics.drawRoundRect(0,0,w,Btns[i].height,10,10);
			Btns[i].graphics.endFill();
			Btns[i].getChildAt(0).x = (w-Btns[i].getChildAt(0).width)/2;
		}
		var offY:int=20;
		for (i=0; i<this.numChildren; i++)
		{
			var c:DisplayObject = this.getChildAt(i);
			c.y = offY;
			c.x = w-c.width+10;
			offY += c.height+5;
		}
		drawStripedRect(this,0,0,w+20,this.height+40,0xAAAAAA,0x999999,20);
		
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	private function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		this.startDrag();
	}//endfunction
	
	private function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
				Fns[i]();	// exec callback function
	}//endfunction
	
	private function onEnterFrame(ev:Event):void
	{
		if (stage==null) return;
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if (Btns[i].filters==null)
					Btns[i].filters=[new GlowFilter(0x99AAFF,1,8,8,2)];
			}
			else
			{
				if (Btns[i].filters!=null)
				{
					var A:Array = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
	}//endfunction
	
	private function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	private static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,10,10);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
		
}//endclass

class WireGrid extends Sprite
{
	public var sc:Number = 1;
	public var center:Point = new Point(0,0);
	public var zoomSlider:Sprite = null;
	
	//=============================================================================================
	// constructor for background grid markings sprite
	//=============================================================================================
	public function WireGrid(w:int,h:int):void
	{
		var ppp:Sprite = this;
		
		function draw(sc:Number):void 
		{
			drawGrid(ppp,w,h,10+50*sc,0x666666);
		}
		zoomSlider = vSlider(10,100,["1","2","3","4","5"],draw);
		zoomSlider.x = 100;
		zoomSlider.y = 100;
		addChild(zoomSlider);
		draw(0);
	}//endfunction

	//=============================================================================================
	// @param	s			sprite to draw into
	// @param	w			width
	// @param	h			height
	// @param	interval	distince between grid lines
	//=============================================================================================
	private function drawGrid(s:Sprite,w:int,h:int,interval:int=10,color:uint=0x666666):void
	{
		s.graphics.clear();
	
		var i:int = 0;
		var n:int = w/interval;
		if (n%2==0)	n--;
		var k:int = (n-1)/2;
		for (i=-k; i<=k; i++)	
		{
			if (i%10==0) s.graphics.lineStyle(0, color, 1);
			else		s.graphics.lineStyle(0, color, 0.5);
			s.graphics.moveTo(w/2+i*interval,0);
			s.graphics.lineTo(w/2+i*interval,h);
		}
		n = h/interval;
		if (n%2==0)	n--;
		k = (n-1)/2;
		for (i=-k; i<=k; i++)	
		{
			if (i%10==0) s.graphics.lineStyle(0, color, 1);
			else		s.graphics.lineStyle(0, color, 0.5);
			s.graphics.moveTo(0,h/2+i*interval);
			s.graphics.lineTo(w,h/2+i*interval);
		}
	}//endfunction
	
	//=============================================================================================
	// creates a vertical slider bar of wxh dimensions  
	//=============================================================================================
	private function vSlider(w:int,h:int,markings:Array,callBack:Function):Sprite
	{
		// ----- main sprite
		var s:Sprite = new Sprite();
		s.graphics.beginFill(0xCCCCCC,1);
		s.graphics.drawRect(0,0,w,h);
		s.graphics.endFill();
		
		// ----- slider knob
		var slider:Sprite = new Sprite();
		slider.graphics.beginFill(0xEEEEEE,1);
		slider.graphics.drawRoundRect(-w,-w/2,w*2,w,w,w);
		slider.graphics.endFill();
		slider.buttonMode = true;
		slider.mouseChildren = false;
		slider.filters = [new DropShadowFilter(2)];
		slider.x = w/2;
		s.addChild(slider);
		
		// ----- draw markings
		s.graphics.lineStyle(0,0x000000,1);
		var n:int = markings.length;
		for (var i:int=0; i<n; i++)
		{
			s.graphics.moveTo(w/2,h/(n-1)*i);
			s.graphics.lineTo(w*3/2,h/(n-1)*i);
			var tf:TextField = new TextField();
			tf.text = markings[i];
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.x = w*2;
			tf.y = h/(n-1)*i-tf.height/2;
			s.addChild(tf);
		}
		
		function updateHandler(ev:Event):void
		{
			if (callBack!=null) callBack(slider.y/h);
		}
		function startDragHandler(ev:Event):void
		{
			slider.startDrag(false,new Rectangle(slider.x,0,0,h));
			stage.addEventListener(Event.ENTER_FRAME,updateHandler);
			stage.addEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
		}
		function stopDragHandler(ev:Event):void
		{
			slider.stopDrag();
			stage.removeEventListener(Event.ENTER_FRAME,updateHandler);
			stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
		}
		slider.addEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
		
		s.x = 100;
		s.y=100;
		return s;
	}//endfunction
}//endclass

class FloorPlan
{
	public var Joints:Vector.<Vector3D>;
	public var Walls:Vector.<Wall>;
	
	/**
	 * 
	 */
	public function FloorPlan():void
	{
		Joints = new Vector.<Vector3D>();
		Walls = new Vector.<Wall>();
	}//endfunction
	
	//=============================================================================================
	//
	//=============================================================================================
	public function createWall(pt1:Vector3D, pt2:Vector3D, width:Number=1, snapDist:Number=10):Wall
	{
		var nearest:Vector3D = null;
		for (var i:int=Joints.length-1; i>-1; i--)
			if (nearest==null || 
				Joints[i].subract(pt1).length<nearest.subtract(pt1).length)
				nearest = Joints[i];
		if (nearest.subtract(pt1).length<snapDist)	pt1=nearest;
		nearest = null;
		for (i=Joints.length-1; i>-1; i--)
			if (Joints[i]!=pt1)
			{
				if (nearest==null || 
					Joints[i].subract(pt1).length<nearest.subtract(pt1).length)
					nearest = Joints[i];
			}
		if (nearest.subtract(pt2).length<snapDist)	pt2=nearest;
		Joints.push(pt1,pt2);
		var wall:Wall = new Wall(pt1, pt2, width);
		Walls.push(wall);
		return wall;
	}//endfunction
	
	//=============================================================================================
	//
	//=============================================================================================
	public function removeWall(wall:Wall):void
	{
		if (Walls.indexOf(wall)!=-1)	Walls.splice(Walls.indexOf(wall),1);
		
		var canRemJt1:Boolean = true;
		var canRemJt2:Boolean = true;
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (w.joint1==wall.joint1 || w.joint2==wall.joint1)	canRemJt1 = false;
			if (w.joint1==wall.joint2 || w.joint2==wall.joint2)	canRemJt2 = false;
		}
		if (canRemJt1 && Joints.indexOf(wall.joint1)!=-1) Joints.splice(Joints.indexOf(wall.joint1),1);
		if (canRemJt2 && Joints.indexOf(wall.joint2)!=-1) Joints.splice(Joints.indexOf(wall.joint2),1);
	}//endfunction
	
	//=============================================================================================
	// finds the nearest joint to this position
	//=============================================================================================
	public function nearestJoint(posn:Vector3D,cutOff:Number):Vector3D
	{
		var joint:Vector3D = null;
		for (var i:int=Joints.length-1; i>-1; i--)
			if (cutOff>Joints[i].subtract(posn).length)
			{
				joint = Joints[i];
				cutOff = joint.subtract(posn).length;
			}
		return joint;
	}//endfunction
	
	//=============================================================================================
	// finds the nearest wall to this position
	//=============================================================================================
	public function nearestWall(posn:Vector3D,cutOff:Number):Wall
	{
		var wall:Wall = null;
		for (var i:int=Walls.length-1; i>-1; i--)
			if (cutOff > Walls[i].perpenticularDist(posn))
			{
				wall = Walls[i];
				cutOff = wall.perpenticularDist(posn);
			}
		return wall;
	}//endfunction
	
	//=============================================================================================
	// returns all walls adjacent to given wall
	//=============================================================================================
	public function adjWalls(wall:Wall) : Vector.<Wall>
	{
		var R:Vector.<Wall> = new Vector.<Wall>();
		for (var i:int=Walls.length-1; i>=-1; i--)
		{
			var w:Wall = Walls[i];
			if (w!=wall &&
				(w.joint1==wall.joint1 || w.joint2==wall.joint2 || w.joint2==wall.joint1 || w.joint1==wall.joint2))
				R.push(w);
		}
		return R;
	}//endfunction
	
	//=============================================================================================
	// refresh draw out existing walls to given sprite s
	//=============================================================================================
	public function draw(s:Sprite):void
	{
		s.graphics.clear();
		var i:int = 0;
		for (i = Walls.length - 1; i > -1; i--)
		{
			var wall:Wall = Walls[i];
			var Pts:Vector.<Point> = wall.wallBounds();
			s.graphics.lineStyle(0,0x000000,1);
			s.graphics.beginFill(0x000000,0.5);
			s.graphics.moveTo(Pts[0].x,Pts[0].y);
			s.graphics.lineTo(Pts[1].x,Pts[1].y);
			s.graphics.lineTo(Pts[2].x,Pts[2].y);
			s.graphics.lineTo(Pts[3].x,Pts[3].y);
			s.graphics.lineTo(Pts[0].x,Pts[0].y);
			s.graphics.endFill();
		}
	}//endfunction
	
	//=======================================================================================
	// find line segments intersect point of lines A=(ax,ay,bx,by) C=(cx,cy,dx,dy)
	// returns null for parrallel segs and point segments, does not detect end points
	//=======================================================================================
	public static function segmentsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number) : Point
	{
		var avx:Number = bx-ax;
		var avy:Number = by-ay;
		var cvx:Number = dx-cx;
		var cvy:Number = dy-cy;
		
		var al:Number = Math.sqrt(avx*avx + avy*avy);	// length of seg A
		var cl:Number = Math.sqrt(cvx*cvx + cvy*cvy);	// length of seg C
		
		if (al==0 || cl==0 || avx/al==cvx/cl || avy/al==cvy/cl)		return null;
		
		// ----- optimization, see actual function below -----------------------------
		var ck:Number = -1;
		if (avx/al==0)		ck = (ax-cx)/cvx*cl;
		else	ck = (cy-ay + (ax-cx)*avy/avx) / (cvx/cl*avy/avx - cvy/cl);
		
		var ak:Number = -1;
		if (cvx/cl==0)		ak = (cx-ax)/avx*al;
		else	ak = (ay-cy + (cx-ax)*cvy/cvx) / (avx/al*cvy/cvx - avy/al);
		
		//var ck:Number = linesCrossScalar(ax,ay,avx/al,avy/al, cx,cy,cvx/cl,cvy/cl);
		//var ak:Number = linesCrossScalar(cx,cy,cvx/cl,cvy/cl, ax,ay,avx/al,avy/al);
			
		if (ak<=0 || ak>=al || ck<=0 || ck>=cl)	return null;
		
		//trace("avx="+avx+"  avy="+avy + "  cvx="+cvx+"  cvy="+cvy);
		
		return new Point(ax + avx/al*ak,ay + avy/al*ak);
	}//endfunction
}//endclass

class Wall
{
	public var joint1:Vector3D;
	public var joint2:Vector3D;
	public var thickness:Number;
	
	/**
	 * 
	 * @param	pt1		end position 1
	 * @param	pt2		end position 2
	 * @param	thick	thickness of wall
	 */
	public function Wall(pt1:Vector3D, pt2:Vector3D, thick:Number=1):void
	{
		joint1 = pt1;
		joint2 = pt2;
		thickness = thick;
	}//endconstr
	
	/**
	 * returns perpendicular dist ffom posn to wall, return MAX_VAL if not within wall bounds
	 * @param	posn
	 * @return
	 */
	public function perpenticularDist(posn:Vector3D):Number
	{
		var wallDir:Vector3D = joint2.subtract(joint1);
		var len:Number = wallDir.length;
		wallDir.normalize();
		
		var ptDir:Vector3D = posn.subtract(joint1);
		var proj:Number = ptDir.dotProduct(wallDir);
		if (proj<0 || proj>len) return Number.MAX_VALUE;
		
		return Math.sqrt(ptDir.lengthSquared - proj*proj);
	}//endfunction
	
	//=======================================================================================
	// returns the 4 corner positions of the wall if it were standalone
	//=======================================================================================
	public function wallBounds():Vector.<Point>
	{
			var dv:Vector3D = joint2.subtract(joint1);
			dv.scaleBy(thickness/dv.length);
			
			return Vector.<Point>([	new Point(joint1.x-dv.x+dv.y,joint1.y-dv.y-dv.x),
									new Point(joint2.x+dv.x+dv.y,joint2.y+dv.y-dv.x),
									new Point(joint2.x+dv.x-dv.y,joint2.y+dv.y+dv.x),
									new Point(joint1.x-dv.x-dv.y,joint1.y-dv.y+dv.x)]);
	}//endfunction
}//endclass