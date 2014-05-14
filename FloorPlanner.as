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
		
		/**
		 * 
		 */
		public function FloorPlanner():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}//
		
		/**
		 * Entry point
		 * @param	e
		 */
		private function init(e:Event=null):void 
		{
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
			gridBg = new Sprite();
			drawGrid(gridBg, stage.stageWidth, stage.stageHeight, 10);
			stage.addChild(gridBg);
			
			// ----- drawing sprite
			floorPlanBg = new Sprite();
			stage.addChild(floorPlanBg);
			
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
				
		/**
		 * defacto mode
		 */
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
		
		/**
		 * create walls step
		 */
		private function addWallsMode():void
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
				var prevLastJoint:Vector3D = lastJoint;
				if (prevLastJoint==null) prevLastJoint = new Vector3D(gridBg.mouseX,gridBg.mouseY);
				lastJoint = new Vector3D(gridBg.mouseX,gridBg.mouseY);
				floorPlan.createWall(prevLastJoint,lastJoint,3);
			}
			mouseUpFn = function():void
			{
				//lastJoint = null;
			}
		}//endfunction
		
		/**
		 * Main Loop
		 * @param	ev
		 */
		private function onEnterFrame(ev:Event):void
		{
			if (stepFn!=null) stepFn();
			titleTf.x = (800-titleTf.width)/2;
			titleTf.y = (600*0.1);
			drawFloorPlan(floorPlanBg);		// update floor plan drawings
		}//endfunction
		
		/**
		 * 
		 * @param	ev
		 */
		private function onMouseDown(ev:Event):void
		{
			if (getTimer()-mouseDownPt.w<300)
			{
				if (mode==0)	{mode=1; titleTf.text="Adding Walls"; addWallsMode();}
				else			{mode=0; titleTf.text="Editing Walls"; editMode();}
			}
			mouseDownPt = new Vector3D(gridBg.mouseX,gridBg.mouseY,0,getTimer());
			if (mouseDownFn!=null) mouseDownFn();
		}//endfunction
		
		/**
		 * 
		 * @param	ev
		 */
		private function onMouseUp(ev:Event):void
		{
			mouseUpPt = new Vector3D(gridBg.mouseX,gridBg.mouseY,0,getTimer());
			if (mouseUpFn!=null) mouseUpFn();
		}//endfunction
		
		/**
		 * 
		 * @param	s			sprite to draw into
		 * @param	w			width
		 * @param	h			height
		 * @param	interval	distince between grid lines
		 */
		private function drawGrid(s:Sprite,w:int,h:int,interval:int=10,color:uint=0x666666):void
		{
			s.graphics.clear();
			
			var i:int = 0;
			var n:int = w/interval;
			for (i=1; i<n; i++)	
			{
				if (i%10==0) s.graphics.lineStyle(0, color, 1);
				else		s.graphics.lineStyle(0, color, 0.5);
				s.graphics.moveTo(i*interval,0);
				s.graphics.lineTo(i*interval,h);
			}
			n = h/interval;
			for (i=1; i<n; i++)	
			{
				if (i%10==0) s.graphics.lineStyle(0, color, 1);
				else		s.graphics.lineStyle(0, color, 0.5);
				s.graphics.moveTo(0,i*interval);
				s.graphics.lineTo(w,i*interval);
			}
		}//endfunction
		
		/**
		 * refresh draw out existing walls
		 * @param	s
		 */
		private function drawFloorPlan(s:Sprite):void
		{
			s.graphics.clear();
			var i:int = 0;
			for (i = floorPlan.Walls.length - 1; i > -1; i--)
			{
				var wall:Wall = floorPlan.Walls[i];
				var dv:Vector3D = wall.joint2.subtract(wall.joint1);
				dv.normalize();
				s.graphics.lineStyle(0,0x000000,1);
				s.graphics.moveTo(wall.joint1.x-dv.y*wall.thickness, wall.joint1.y+dv.x*wall.thickness);
				s.graphics.lineTo(wall.joint2.x-dv.y*wall.thickness, wall.joint2.y+dv.x*wall.thickness);
				s.graphics.moveTo(wall.joint1.x+dv.y*wall.thickness, wall.joint1.y-dv.x*wall.thickness);
				s.graphics.lineTo(wall.joint2.x+dv.y*wall.thickness, wall.joint2.y-dv.x*wall.thickness);
			}
		}//endfunction
	}//endclass
	
}

import flash.geom.Vector3D;

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
	
	/**
	 * 
	 */
	public function createWall(pt1:Vector3D, pt2:Vector3D, width:Number=1, snapDist:Number=10):Boolean
	{
		var wall:Wall = new Wall(pt1, pt2, width);
		Walls.push(wall);
		if (Joints.indexOf(pt1)==-1) Joints.push(pt1);
		if (Joints.indexOf(pt2)==-1) Joints.push(pt2);
		return wall;
	}//endfunction
	
	/**
	 * finds the nearest joint to this position
	 * @param	pt
	 */
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
	
	/**
	 * finds the nearest wall to this position
	 * @param	pt
	 */
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
}//endclass