using rssnews.Models;

namespace rssnews.GraphQL.InputType
{
    public class AuthorInputType : InputObjectType<Author>
    {
        protected override void Configure(IInputObjectTypeDescriptor<Author> descriptor)
        {
            descriptor.Name("AuthorInput");
            descriptor.Field(a => a.AuthorID).Type<NonNullType<StringType>>();
            descriptor.Field(a => a.FirstName).Type<NonNullType<StringType>>();
            descriptor.Field(a => a.LastName).Type<NonNullType<StringType>>();
        }
    }
}