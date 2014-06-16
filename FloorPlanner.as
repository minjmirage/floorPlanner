package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.utils.getTimer;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	[SWF(width = "800", height = "600", backgroundColor = "#FFFFFF", frameRate = "30")];
	
	/**
	 * ...
	 * @author mj
	 */
	public class FloorPlanner extends Sprite 
	{
		private var mouseDownPt:Vector3D = null;
		private var mouseUpPt:Vector3D= null;
		private var grid:WireGrid = null;
		private var floorPlan:FloorPlan = null;
		
		private var menu:Sprite = null;
		
		private var stepFn:Function = null;
		private var mouseDownFn:Function = null;
		private var mouseUpFn:Function = null;
		
		private var titleTf:TextField = null;
		
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
			stage.align = "topLeft";
			removeEventListener(Event.ADDED_TO_STAGE, init);
					
			mouseDownPt = new Vector3D();
			mouseUpPt = new Vector3D();
			
			var sw:int = stage.stageWidth;
			var sh:int = stage.stageHeight;
			
			// ----- add grid background
			grid = new WireGrid(sw,sh);
			grid.x = sw/2;
			grid.y = sh/2;
			grid.update();
			addChild(grid);
			
			// ----- drawing sprite
			floorPlan = new FloorPlan();
			floorPlan.buttonMode = true;
			grid.addChild(floorPlan);
			
			// ----- enter default editing mode
			modeDefault();
			
			createDefaRoom();
			
			// ----- add controls
			stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}//endfunction
		
		//=============================================================================================
		// default room to look at just so it wouldnt be too boring 
		//=============================================================================================
		private function createDefaRoom():void
		{
			floorPlan.createWall(new Vector3D( -200, -200), new Vector3D(200, -200),10);
			floorPlan.createWall(new Vector3D( 200, -200), new Vector3D(200, 200),10);
			floorPlan.createWall(new Vector3D( 200, 200), new Vector3D( -200, 200),10);
			floorPlan.createWall(new Vector3D( -200, 200), new Vector3D( -200, -200), 10);
			floorPlan.Walls[2].Doors.push(new Door(0.35, 0.3));
		}//endfunction
		
		//=============================================================================================
		// go into defacto mode
		//=============================================================================================
		private function modeDefault():void
		{
			prn("modeDefault");
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("EDITING MODE",
									Vector.<String>(["ADD WALLS","ADD DOORS","ADD WINDOWS","ADD FURNITURE"]),
									Vector.<Function>([modeAddWalls,modeAddDoors,modeAddWindows,modeAddWalls]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- default editing logic
			var lastJoint:Vector3D = null;
			var lastWall:Wall = null;
			var prevMousePt:Point = new Point(0,0);
			stepFn = function():void
			{
				if (lastJoint!=null)
				{	// shift joint
					lastJoint.x = grid.mouseX;
					lastJoint.y = grid.mouseY;
				}
				else if (lastWall != null)
				{	// ----- shift wall
					lastWall.joint1.x += grid.mouseX - prevMousePt.x;
					lastWall.joint1.y += grid.mouseY - prevMousePt.y;
					lastWall.joint2.x += grid.mouseX - prevMousePt.x;
					lastWall.joint2.y += grid.mouseY - prevMousePt.y;
				}
				else if (mouseDownPt.w>mouseUpPt.w)
				{	// ----- shift grid background
					grid.x += (grid.mouseX - prevMousePt.x)*grid.scaleX;
					grid.y += (grid.mouseY - prevMousePt.y)*grid.scaleY;
					grid.update();
				}
				prevMousePt.x = grid.mouseX;
				prevMousePt.y = grid.mouseY;
			}
			mouseDownFn = function():void
			{
				prevMousePt.x = grid.mouseX;
				prevMousePt.y = grid.mouseY;
				lastJoint = floorPlan.nearestJoint(mouseDownPt, 10);		// chk if near any joint
				if (lastJoint==null)
					lastWall = floorPlan.nearestWall(mouseDownPt, 10);		// chk if near any wall
			}
			mouseUpFn = function():void
			{
				lastJoint = null;
				lastWall = null;
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding walls mode
		//=============================================================================================
		private function modeAddWalls(snapDist:Number=10):void
		{
			prn("modeAddWalls");
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING WALLS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
		
			// ----- add walls logic
			var wall:Wall = null;
			stepFn = function():void
			{
				if (wall!=null)
				{
					wall.joint2.x = grid.mouseX;
					wall.joint2.y = grid.mouseY;
					var collided:Wall = floorPlan.chkWallCollide(wall);
					if (collided != null)
					{
						var intercept:Vector3D = floorPlan.projectedWallPosition(collided, wall.joint2);
						floorPlan.removeWall(collided);
						floorPlan.createWall(collided.joint1, intercept,snapDist);
						floorPlan.createWall(collided.joint2, intercept, snapDist);
						floorPlan.removeWall(wall);
						floorPlan.createWall(wall.joint1, intercept,snapDist);
						wall = null;
					}
				}
			}
			mouseDownFn = function():void
			{
				if (wall==null)
					wall = floorPlan.createWall(new Vector3D(grid.mouseX,grid.mouseY),
												new Vector3D(grid.mouseX,grid.mouseY),
												snapDist);
			}
			mouseUpFn = function():void
			{
				if (wall!=null && wall.joint1.subtract(wall.joint2).length<=snapDist)
					floorPlan.removeWall(wall);		// remove wall stub
				wall = null;
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddDoors(snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING DOORS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- add doors logic
			var prevWall:Wall = null;
			var door:Door = null;
			stepFn = function():void
			{
				// ----- remove added display door
				if (prevWall!=null)
				{	
					if (prevWall.Doors.indexOf(door)!=-1)
						prevWall.Doors.splice(prevWall.Doors.indexOf(door),1);
				}
				
				var mouseP:Vector3D = new Vector3D(grid.mouseX,grid.mouseY,0);
				
				var near:Wall = floorPlan.nearestWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	doorP = chkPlaceDoor(near, mouseP, 100);	// chk place door of 100 width
				// ----- if in position to place door
				if (near!=null && doorP!=null)
				{
					if (door==null) 	
						door = new Door(doorP.x,doorP.y-doorP.x);
					else
						door.pivot = doorP.x;
					
					near.Doors.push(door);
					prevWall = near;
				}
				// ----- if not in legal position to show door
			}//endfunction
			mouseDownFn = function():void
			{
				
			}
			mouseUpFn = function():void
			{
				prevWall = null;	// forget about the last placed door
				door = null;
			}
		}//endfunction
		
		//=============================================================================================
		// go into adding doors mode
		//=============================================================================================
		private function modeAddWindows(snapDist:Number=10):void
		{
			var px:int = 0;
			var py:int = 0;
			if (menu!=null)
			{
				if (menu.parent!=null) menu.parent.removeChild(menu);
				px = menu.x;
				py = menu.y;
			}
			menu = new ButtonsMenu("ADDING WINDOWS",
									Vector.<String>(["DONE"]),
									Vector.<Function>([modeDefault]));
			menu.x = px;
			menu.y = py;
			stage.addChild(menu);
			
			// ----- add doors logic
			var prevWall:Wall = null;
			var door:Door = null;
			stepFn = function():void
			{
				// ----- remove added display door
				if (prevWall!=null)
				{	
					if (prevWall.Doors.indexOf(door)!=-1)
						prevWall.Doors.splice(prevWall.Doors.indexOf(door),1);
				}
				
				var mouseP:Vector3D = new Vector3D(grid.mouseX,grid.mouseY,0);
				
				var near:Wall = floorPlan.nearestWall(mouseP,snapDist);
				var doorP:Point = null;
				if (near!=null)	doorP = chkPlaceDoor(near, mouseP, 60);	// chk place door of 60 width
				// ----- if in position to place door
				if (near!=null && doorP!=null)
				{
					if (door == null) 
					{
						door = new Door(doorP.x, doorP.y - doorP.x);
						door.angR = 0;
						door.thickness = 20;
					}
					else
						door.pivot = doorP.x;
					
					near.Doors.push(door);
					prevWall = near;
				}
				// ----- if not in legal position to show door
			}//endfunction
			mouseDownFn = function():void
			{
				
			}
			mouseUpFn = function():void
			{
				prevWall = null;	// forget about the last placed door
				door = null;
			}
		}//endfunction
		
		//=============================================================================================
		// returns whether door of width can be placed at position pt along given wall 
		//=============================================================================================
		private function chkPlaceDoor(wall:Wall, pt:Vector3D, width:Number):Point
		{
			var wallV:Vector3D = wall.joint2.subtract(wall.joint1);
			var wallL:Number = wallV.length; 
			wallV.normalize();
			var proj:Number = pt.subtract(wall.joint1).dotProduct(wallV);	// ratio along wall where door is at
			var a:Number = proj/wallL-0.5*width/wallL;	// door span along wallL
			var b:Number = proj/wallL+0.5*width/wallL;
			if (a<0 || b>1)	return null;	//exceed wall limit
			
			for (var i:int=wall.Doors.length-1; i>-1; i--)		// check if overlap other doors
			{
				var c:Number = wall.Doors[i].pivot;
				var d:Number = wall.Doors[i].dir+c;
				if (d<c)
				{
					var tmp:Number = d;
					d = c;
					c = tmp;
				}
				if ((a>c && a<d) || (b>c && b<d))
					return null;
			}
			return new Point(a,b);
		}//endfunction
		
		//=============================================================================================
		// Main Loop
		//=============================================================================================
		private function onEnterFrame(ev:Event):void
		{
			if (stepFn!=null) stepFn();
			floorPlan.draw();		// update floor plan drawings
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseDown(ev:Event):void
		{
			if (menu!=null && menu.hitTestPoint(stage.mouseX,stage.mouseY)) return;
			mouseDownPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseDownFn!=null) mouseDownFn();
		}//endfunction
		
		//=============================================================================================
		//
		//=============================================================================================
		private function onMouseUp(ev:Event):void
		{
			mouseUpPt = new Vector3D(grid.mouseX,grid.mouseY,0,getTimer());
			if (mouseUpFn!=null) mouseUpFn();
		}//endfunction
		
		//=============================================================================================
		// debug printout function
		//=============================================================================================
		private var debugTf:TextField;
		private function prn(s:String):void
		{
			if (debugTf==null)
			{
				debugTf = new TextField();
				debugTf.autoSize = "left";
				debugTf.wordWrap = false;
				debugTf.mouseEnabled = false;
				var tff:TextFormat = debugTf.defaultTextFormat;
				tff.color = 0xFFFFFF;
				debugTf.defaultTextFormat = tff;
				debugTf.text = "";
				addChild(debugTf);
			}
		
			debugTf.appendText(s+"\n");
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
		titleTf.selectable = false;
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
			{
				Fns[i]();	// exec callback function
				return;
			}
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
	public var sw:int = 800;
	public var sh:int = 600;
	public var zoomSlider:Sprite = null;
	
	//=============================================================================================
	// constructor for background grid markings sprite
	//=============================================================================================
	public function WireGrid(w:int,h:int):void
	{
		sw = w;
		sh = h;
		
		function draw(f:Number):void 
		{
			zoom(f*4+1);
		}
		zoomSlider = vSlider(10,100,["1","2","3","4","5"],draw);
		addChild(zoomSlider);
		update();
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function zoom(sc:Number):void
	{
		scaleX = scaleY = sc;
		update();
	}//endfunction
	
	//=============================================================================================
	// redraws the grid background so the grid lines always cover the screen
	//=============================================================================================
	public function update():void
	{
		var interval:int = 10;
		var rect:Rectangle = new Rectangle(-x/scaleX,-y/scaleY,sw/scaleX,sh/scaleY);	// define rectangle to draw
		
		// ----- draw bg color
		graphics.clear();
		graphics.beginFill(0x99AAFF,1);
		graphics.drawRect(rect.x,rect.y,rect.width,rect.height);
		graphics.endFill();
		
		// ----- draw grid lines
		var i:int = 0;
		var a:int = int(rect.left/interval)*interval;
		for (i=a; i<=rect.right; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0x666666, 1);
			else					graphics.lineStyle(0, 0x999999, 1);
			graphics.moveTo(i,rect.top);
			graphics.lineTo(i,rect.bottom);
		}
		a = int(rect.top/interval)*interval;
		for (i=a; i<=rect.bottom; i+=interval)	
		{
			if (i%(interval*10)==0)	graphics.lineStyle(0, 0x666666, 1);
			else					graphics.lineStyle(0, 0x999999, 1);
			graphics.moveTo(rect.left,i);
			graphics.lineTo(rect.right,i);
		}
		
		// ----- scale and place zoom slider 
		zoomSlider.scaleX = 1/scaleX;
		zoomSlider.scaleY = 1/scaleY;
		zoomSlider.x = rect.left+rect.width*0.9;
		zoomSlider.y = rect.top+rect.height*0.1;
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

class FloorPlan extends Sprite
{
	public var Joints:Vector.<Vector3D>;
	public var Walls:Vector.<Wall>;
	
	//=============================================================================================
	//
	//=============================================================================================
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
		// ----- snap pt1 to existing joint
		var nearest:Vector3D = null;
		for (var i:int=Joints.length-1; i>-1;i--)
			if (nearest==null || Joints[i].subtract(pt1).length<nearest.subtract(pt1).length)
				nearest=Joints[i];
		if (nearest!=null && nearest.subtract(pt1).length<snapDist)	
			pt1 = nearest;
		else
			Joints.push(pt1);
		
		// ----- snap pt2 to existing joint not pt1
		nearest = null;
		for (i=Joints.length-1; i>-1; i--)
			if (Joints[i]!=pt1)
			{
				if (nearest==null || Joints[i].subtract(pt2).length<nearest.subtract(pt2).length)
					nearest=Joints[i];
			}
		if (nearest!=null && nearest.subtract(pt2).length<snapDist)	
			pt2 = nearest;
		else
			Joints.push(pt2);
		
		// ----- register new wall
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
	// returns wall that collided with given wall or null 
	//=============================================================================================
	public function chkWallCollide(wall:Wall):Wall
	{
		for (var i:int=Walls.length-1; i>-1; i--)
		{
			var w:Wall = Walls[i];
			if (segmentsIntersectPt(w.joint1.x,w.joint1.y,w.joint2.x,w.joint2.y, wall.joint1.x,wall.joint1.y,wall.joint2.x,wall.joint2.y)!=null)
				return w;
		}
		
		return null;
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function projectedWallPosition(wall:Wall, pt:Vector3D) : Vector3D
	{
		var vpt:Vector3D = pt.subtract(wall.joint1);
		var dir:Vector3D = wall.joint2.subtract(wall.joint1);
		dir.normalize();
		var k:Number = vpt.dotProduct(dir);
		
		return new Vector3D(wall.joint1.x + dir.x*k, wall.joint1.y + dir.y * k);;
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	public function draw():void
	{
		graphics.clear();
		
		for (var i:int=Walls.length-1; i>-1; i--)	// draw for each wall
			drawWall(Walls[i]);
	}//endfunction
	
	//=============================================================================================
	// draws wall with any door and windows on it
	//=============================================================================================
	private function drawWall(wall:Wall):void
	{
		// ----- draw wall bounds
		var wallB:Vector.<Point> = wall.wallBounds(false);
				
		var ipt:Point = null;
		var j:int=0;
		var wb:Vector.<Point>=null;
		var Adj:Vector.<Wall> = connectedToJoint(wall.joint2);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint2)		wb = Adj[j].wallBounds(true);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(false);
			
			ipt = segmentsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[1] = ipt;
			ipt = segmentsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[2] = ipt;
		}
		
		Adj = connectedToJoint(wall.joint1);
		for (j=Adj.length-1; j>-1; j--)
		{
			wb = null;
			if (Adj[j].joint2==wall.joint1)		wb = Adj[j].wallBounds(false);	// ensure point ordering is correct
			else								wb = Adj[j].wallBounds(true);
			
			ipt = segmentsIntersectPt(wallB[0].x,wallB[0].y,wallB[1].x,wallB[1].y,wb[0].x,wb[0].y,wb[1].x,wb[1].y);
			if (ipt!=null)	wallB[0] = ipt;
			ipt = segmentsIntersectPt(wallB[3].x,wallB[3].y,wallB[2].x,wallB[2].y,wb[3].x,wb[3].y,wb[2].x,wb[2].y);
			if (ipt!=null)	wallB[3] = ipt;
		}
		
		graphics.lineStyle(0,0x000000,1);
		graphics.beginFill(0x000000,0.5);
		graphics.moveTo(wallB[0].x,wallB[0].y);
		graphics.lineTo(wallB[1].x,wallB[1].y);
		graphics.lineTo(wallB[2].x,wallB[2].y);
		graphics.lineTo(wallB[3].x,wallB[3].y);
		graphics.lineTo(wallB[0].x,wallB[0].y);
		graphics.endFill();
		
		// ----- draw all doors
		for (j=wall.Doors.length-1; j>-1; j--)
		{
			var door:Door = wall.Doors[j];
			var piv:Point = new Point(	wall.joint1.x + (wall.joint2.x-wall.joint1.x)*door.pivot,
										wall.joint1.y + (wall.joint2.y-wall.joint1.y)*door.pivot);
			var dir:Point = new Point(	(wall.joint2.x-wall.joint1.x)*door.dir,
										(wall.joint2.y-wall.joint1.y)*door.dir);
			var bearing:Number = Math.atan2(dir.x,-dir.y);
			var angL:Number = bearing+door.angL;
			var angR:Number = bearing+door.angR;
			graphics.lineStyle(0,0x000000,1);
			var cnt:int = 0;
			graphics.moveTo(piv.x,piv.y);
			for (var deg:Number=angL; deg<angR; deg+=Math.PI/32)
			{
				if (cnt%2==0)
					graphics.lineTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				else
					graphics.moveTo(piv.x+Math.sin(deg)*dir.length,piv.y-Math.cos(deg)*dir.length);
				cnt++;
			}
			drawBar(piv,piv.add(new Point(Math.sin(angL)*dir.length,-Math.cos(angL)*dir.length)),door.thickness);
			drawBar(piv,piv.add(new Point(Math.sin(angR)*dir.length,-Math.cos(angR)*dir.length)),door.thickness);
		}
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	private function drawBar(from:Point,to:Point,thickness:Number):void
	{
		var dir:Point = to.subtract(from);
		var dv:Point = new Point(dir.x/dir.length*thickness/2,dir.y/dir.length*thickness/2);
		graphics.beginFill(0xCCCCCC,1);
		graphics.moveTo(from.x-dv.y,from.y+dv.x);
		graphics.lineTo(from.x+dv.y,from.y-dv.x);
		graphics.lineTo(to.x+dv.y,to.y-dv.x);
		graphics.lineTo(to.x-dv.y,to.y+dv.x);
		graphics.endFill();
	}//endfunction
	
	//=============================================================================================
	// 
	//=============================================================================================
	private function connectedToJoint(pt:Vector3D):Vector.<Wall>
	{
		var W:Vector.<Wall> = new Vector.<Wall>();
		for (var i:int=Walls.length-1; i>-1; i--)
			if (Walls[i].joint1==pt || Walls[i].joint2==pt)
				W.push(Walls[i]);
		return W;
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
	public var Doors:Vector.<Door>;
	
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
		Doors = new Vector.<Door>();
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
	public function wallBounds(from2:Boolean=false):Vector.<Point>
	{
		var j1:Vector3D = joint1;
		var j2:Vector3D = joint2;
		if (from2)
		{
			j2 = joint1;
			j1 = joint2;
		}
		
		var dv:Vector3D = j2.subtract(j1);
		dv.scaleBy(thickness/dv.length);
		
		return Vector.<Point>([	new Point(j1.x-dv.x+dv.y,j1.y-dv.y-dv.x),
								new Point(j2.x+dv.x+dv.y,j2.y+dv.y-dv.x),
								new Point(j2.x+dv.x-dv.y,j2.y+dv.y+dv.x),
								new Point(j1.x-dv.x-dv.y,j1.y-dv.y+dv.x)]);
	}//endfunction
}//endclass

class Door
{
	public var pivot:Number;	// a ratio from joint1 to joint2 of wall	
	public var dir:Number;		// an added ratio relative to pivot
	public var angL:Number=0;
	public var angR:Number=Math.PI/2;
	public var thickness:Number=10;
	
	public function Door(piv:Number,wid:Number):void
	{
		pivot = piv;
		dir = wid;
	}
}//endfunction