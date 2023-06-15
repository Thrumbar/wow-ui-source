--These are interfaces that are called in shared code and need to be defined, but don't need a real implementation in Classic.

--EditModeManagerFrame

EditModeManagerFrame = {}

function EditModeManagerFrame:IsEditModeActive()
	return false;
end

--HelpTip

HelpTip = {}

function HelpTip:Show( p1, p2 )
end

function HelpTip:Hide( p1, p2 )
end

HelpTip.ButtonStyle = {
	None = 1,
	Close = 2,
	Okay = 3,
	GotIt = 4,
	Next = 5,
};

HelpTip.Point = {
	TopEdgeLeft = 1,
	TopEdgeCenter = 2,
	TopEdgeRight = 3,
	BottomEdgeLeft = 4,	
	BottomEdgeCenter = 5,
	BottomEdgeRight = 6,
	RightEdgeTop = 7,
	RightEdgeCenter = 8,
	RightEdgeBottom = 9,
	LeftEdgeTop = 10,
	LeftEdgeCenter = 11,
	LeftEdgeBottom = 12,
};

ActionButtonBindingHighlightCallbackRegistry = {}

function ActionButtonBindingHighlightCallbackRegistry:RegisterCallbackWithHandle(p1, p2, p3)
end