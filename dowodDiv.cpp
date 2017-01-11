
#include <cstdio>
#include <cstdlib>

using namespace std;
int main(){

	int a = 123456789;
	int b = 1234567;
	int c = 1234567;
	int d = 1;

	while(a > b){
		b = b * 2;
		printf("B;%d\n",b);
		if(d == 0)
			d++;
		else
			d = d * 2;
		printf("D:%d\t",d);
	}
	b /= 2;
	d /= 2;
	a = a - b;
	b = c;
	printf("\n");
	while(a > b){
		a = a - b;
		d = d + 1;
	}
	printf("Wynik:%d\n",d);

}
