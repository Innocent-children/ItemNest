import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { CardContent, CardService } from '../services/CardService';

export default class ItemNestForm extends FormExtensionAbility {
  onAddForm(want:Want):formBindingData.FormBindingData {
    const id=String(want.parameters?.['ohos.extra.param.key.form_identity']??'');
    const content=new CardContent();content.wide=Number(want.parameters?.['ohos.extra.param.key.form_dimension'])===3;
    if(id)CardService.update(this.context,id,content.wide?3:2).catch(()=>{});
    return formBindingData.createFormBindingData(content);
  }
  onUpdateForm(id:string):void { CardService.update(this.context,id).catch(()=>{}); }
}
