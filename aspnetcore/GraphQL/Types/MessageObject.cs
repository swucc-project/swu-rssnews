using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public class MessageObject : ObjectType<Message>
    {
        protected override void Configure(IObjectTypeDescriptor<Message> descriptor)
        {
            descriptor.Field(m => m.Id).Type<NonNullType<StringType>>();
            descriptor.Field(m => m.Content).Type<NonNullType<StringType>>();
            descriptor.Field(m => m.Type).Type<NonNullType<StringType>>();
            descriptor.Field(m => m.Timestamp).Type<NonNullType<DateTimeType>>();
            descriptor.Field(m => m.UserId).Type<StringType>();
            descriptor.Field(m => m.Metadata);
        }
    }
}