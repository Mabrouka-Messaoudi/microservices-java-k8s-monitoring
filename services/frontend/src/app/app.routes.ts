import {Routes} from '@angular/router';
import {HomePageComponent} from "./pages/home-page/home-page.component";
import {AddProductComponent} from "./pages/add-product/add-product.component";
import {AddInventoryComponent} from "./pages/add-inventory/add-inventory.component";

export const routes: Routes = [
  {path: '', component: HomePageComponent},
  {path: 'add-product', component: AddProductComponent},
  { path: 'add-inventory', component: AddInventoryComponent }
];
