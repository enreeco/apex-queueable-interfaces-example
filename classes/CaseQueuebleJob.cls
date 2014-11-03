/*
 * Author: Enrico Murru @enreeco
 * Site: http://about.me/enreeco
 */
public class CaseQueuebleJob implements Queueable, Database.AllowsCallouts {
    
    /*
     * Class used to convey case fields
	 */
    public class CalloutBody{
        public CalloutBody(){
            this.values = new Map<String,Object>();
        }
        public Map<String,Object> values{get;set;}
    }
    
    /*
     * Case passed on class creation (the actual ticket from the Trigger)
	 */
    private Case ticket{get;Set;}
    
    /*
     * Constructor
     */
    public CaseQueuebleJob(Case ticket){
        this.ticket = ticket;
    }
    
    /*
     * Interface method. 
     * Creates the map of non-null Case fields, gets the Callout__c object
     * depending on current context JobID.
     * In case of failure, the job is queued again.
     */
    public void execute(QueueableContext context) {
    	//1 - creates the callout payload
        String reqBody = JSON.serialize(createFromCase(this.ticket));
        
        //2 - gets the already created Callout__c object
        Callout__c currentCallout = [Select Id, Status__c, Sent_on__c, Response__c, Case__c,
                                     Job_ID__c From Callout__c Where Job_ID__c = :context.getJobId()];
        
        //3 - starting time (to get Duration__c)
        Long start = System.now().getTime();
        
        //4 - tries to make the REST call
        try{
            Http h = new Http();
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            //change this to another bin @ http://requestb.in
            request.setEndpoint('http://requestb.in/nigam7ni');
            request.setTimeout(60000);
            request.setBody(reqBody);
            HttpResponse response = h.send(request);
            
            //4a - Response OK
            if(response.getStatusCode() == 200){
            	currentCallout.status__c = 'OK';
            //4b - Reponse KO
            }else{
                currentCallout.status__c = 'KO';
            }
            //4c - saves the response body
            currentCallout.Response__c = response.getBody();
        }catch(Exception e){
        	//5 - callout failed (e.g. timeout)
            currentCallout.status__c = 'Failed';
            currentCallout.Response__c = e.getStackTraceString().replace('\n',' / ')+' - '+e.getMessage();
            
            //6 - it would have been cool to reschedule the job again :(
            /*
             * Apprently this cannot be done due to "Maximum callout depth has been reached." exception
            ID jobID = System.enqueueJob(new CaseQueuebleJob(this.ticket));
            Callout__c retry = new Callout__c(Job_ID__c = jobID, 
                                                 Case__c = this.ticket.Id,
												Status__c = 'Queued');
            insert retry;
			*/
        }
        //7 - sets various info about the job
        currentCallout.Sent_on__c = System.now();
        currentCallout.Duration__c = system.now().getTime()-start;
        update currentCallout;
        
        //8 - created an Attachment with the request sent (it could be used to manually send it again with a bonification tool)
        Attachment att = new Attachment(Name = 'request.json', 
                                        Body = Blob.valueOf(reqBody), 
                                        ContentType='application/json',
                                       ParentId = currentCallout.Id);
		insert att;
    }
    
    /*
     * This handles the logic before callout body creation (it takes all non-null fields
     * and removes the "__c" on their names)
	 */
    private static CalloutBody createFromCase(Case ticket){
        CalloutBody calloutBody = new CalloutBody();
        //describes Case sobject to create the call body
        Map<String, Schema.SObjectField> fields = Case.getSobjectType().getDescribe().fields.getMap();
        for(String key : fields.keyset()){
            Object obj = ticket.get(key);
            if(obj != null){
            	calloutBody.values.put(key.replace('__c','').toLowerCase(), obj);
			}
        }
        return calloutBody;
    }
    
}