active proctype Qchan() {
	mtype:msgs M;
	bit b0;
	bit b1;
	do
	:: AtoC ? M,b0,b1; CtoB ! M,b0,b1;
	:: BtoC ? M,b0,b1; CtoA ! M,b0,b1;
	od
}